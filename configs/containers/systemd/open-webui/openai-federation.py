import asyncio
import logging
import os
from pathlib import Path
from time import monotonic

from aiohttp import ClientError, ClientSession, ClientTimeout, DummyCookieJar, WSMsgType, web


OPENAI_API = "https://api.openai.com"
OPENAI_TOKEN_URL = "https://auth.openai.com/oauth/token"
TOKEN_TIMEOUT = ClientTimeout(total=15)
PROXY_TIMEOUT = ClientTimeout(total=None, connect=15, sock_read=600)
LOG = logging.getLogger(__name__)


async def relay_messages(source, destination):
    async for message in source:
        if message.type == WSMsgType.TEXT:
            await destination.send_str(message.data)
        elif message.type == WSMsgType.BINARY:
            await destination.send_bytes(message.data)
        elif message.type == WSMsgType.ERROR:
            raise ConnectionError("WebSocket transport failed")


class OpenAIProxy:
    def __init__(self, session: ClientSession):
        self.session = session
        self.pocket_id_url = os.environ["POCKET_ID_TOKEN_URL"]
        self.pocket_id_fields = {
            "grant_type": "client_credentials",
            "client_id": os.environ["POCKET_ID_CLIENT_ID"],
            "client_secret": Path("/run/secrets/open-webui-pocket-id-client-secret").read_text().strip(),
            "resource": OPENAI_API,
            "scope": "openai:exchange",
        }
        self.openai_fields = {
            "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
            "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
            "identity_provider_id": os.environ["OPENAI_IDENTITY_PROVIDER_ID"],
            "service_account_id": os.environ["OPENAI_SERVICE_ACCOUNT_ID"],
        }
        if not self.pocket_id_fields["client_secret"]:
            raise ValueError("Pocket ID client secret is empty")

        self.token = ""
        self.refresh_at = 0.0
        self.refresh_lock = asyncio.Lock()

    async def access_token(self) -> str:
        if monotonic() < self.refresh_at:
            return self.token

        async with self.refresh_lock:
            if monotonic() < self.refresh_at:
                return self.token

            async with self.session.post(
                self.pocket_id_url, data=self.pocket_id_fields,
                timeout=TOKEN_TIMEOUT, allow_redirects=False, raise_for_status=True,
            ) as response:
                subject_token = (await response.json())["access_token"]

            if not isinstance(subject_token, str) or not subject_token:
                raise ValueError("Pocket ID returned an empty access token")

            started = monotonic()
            async with self.session.post(
                OPENAI_TOKEN_URL, json={**self.openai_fields, "subject_token": subject_token},
                timeout=TOKEN_TIMEOUT, allow_redirects=False, raise_for_status=True,
            ) as response:
                credential = await response.json()

            token = credential["access_token"]
            lifetime = credential["expires_in"]
            if not isinstance(token, str) or not token or not isinstance(lifetime, int) or lifetime <= 0:
                raise ValueError("OpenAI returned an invalid token or expiration")

            self.token = token
            self.refresh_at = started + lifetime - min(60, lifetime / 2)
            return token

    async def forward(self, request: web.Request) -> web.StreamResponse:
        try:
            token = await self.access_token()
        except (ClientError, TimeoutError, KeyError, TypeError, ValueError) as error:
            LOG.warning("Federation failed (%s, HTTP %s)", type(error).__name__, getattr(error, "status", "-"))
            return web.json_response({"error": {"message": "OpenAI token exchange failed"}}, status=502)

        if request.path == "/v1/realtime":
            return await self.forward_realtime(request, token)

        headers = {
            name: request.headers[name]
            for name in ("Accept", "Content-Type", "Content-Length")
            if name in request.headers
        }
        headers["Authorization"] = f"Bearer {token}"
        try:
            upstream = await self.session.request(
                request.method, OPENAI_API + request.path,
                params=request.query, headers=headers, allow_redirects=False,
                data=request.content if request.can_read_body else None,
            )
        except (ClientError, TimeoutError) as error:
            LOG.warning("OpenAI request failed (%s)", type(error).__name__)
            return web.json_response({"error": {"message": "OpenAI is unavailable"}}, status=502)

        async with upstream:
            if upstream.status == 401 and token == self.token:
                self.refresh_at = 0.0

            response_headers = {
                name: upstream.headers[name]
                for name in ("Content-Type", "Retry-After", "X-Request-Id")
                if name in upstream.headers
            }
            response = web.StreamResponse(status=upstream.status, headers=response_headers)
            await response.prepare(request)
            async for chunk in upstream.content.iter_any():
                await response.write(chunk)
            return response

    async def forward_realtime(self, request: web.Request, token: str) -> web.StreamResponse:
        downstream = web.WebSocketResponse()
        if not downstream.can_prepare(request).ok:
            raise web.HTTPBadRequest(text="Expected a WebSocket upgrade")

        try:
            async with asyncio.timeout(15):
                upstream = await self.session.ws_connect(
                    OPENAI_API + request.path,
                    params=request.query,
                    headers={"Authorization": f"Bearer {token}"},
                )
        except (ClientError, TimeoutError) as error:
            status = getattr(error, "status", None)
            if status == 401 and token == self.token:
                self.refresh_at = 0.0
            LOG.warning("OpenAI Realtime handshake failed (%s, HTTP %s)", type(error).__name__, status)
            return web.json_response({"error": {"message": "OpenAI Realtime is unavailable"}}, status=502)

        async with upstream:
            await downstream.prepare(request)

            async def relay_to_client():
                try:
                    await relay_messages(upstream, downstream)
                except (ClientError, ConnectionError) as error:
                    LOG.warning("OpenAI Realtime relay ended (%s)", type(error).__name__)
                finally:
                    await downstream.close()

            from_upstream = asyncio.create_task(relay_to_client())
            try:
                await relay_messages(downstream, upstream)
            except (ClientError, ConnectionError) as error:
                LOG.warning("OpenAI Realtime relay ended (%s)", type(error).__name__)
            finally:
                from_upstream.cancel()
                await asyncio.gather(from_upstream, return_exceptions=True)
                await downstream.close()

        return downstream


async def make_app() -> web.Application:
    app = web.Application()
    proxy_context = web.AppKey("openai_proxy", OpenAIProxy)

    async def setup_proxy(app: web.Application):
        async with ClientSession(timeout=PROXY_TIMEOUT, cookie_jar=DummyCookieJar()) as session:
            app[proxy_context] = OpenAIProxy(session)
            yield

    async def forward(request: web.Request) -> web.StreamResponse:
        return await request.app[proxy_context].forward(request)

    app.cleanup_ctx.append(setup_proxy)
    app.router.add_get("/v1/models", forward, allow_head=False)
    app.router.add_get("/v1/realtime", forward, allow_head=False)
    app.router.add_post("/v1/chat/completions", forward)
    app.router.add_post("/v1/responses", forward)
    app.router.add_post("/v1/embeddings", forward)
    app.router.add_post("/v1/audio/speech", forward)
    app.router.add_post("/v1/audio/transcriptions", forward)
    app.router.add_post("/v1/images/generations", forward)
    app.router.add_post("/v1/images/edits", forward)
    return app


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    web.run_app(make_app(), host="127.0.0.1", port=8090, access_log=None, handler_cancellation=True)
