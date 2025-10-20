#!/usr/bin/env bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE USER synapse WITH PASSWORD '${secrets.synapse_postgres_password}';
  CREATE DATABASE synapse;
  GRANT ALL PRIVILEGES ON DATABASE synapse TO synapse;

  CREATE USER mas WITH PASSWORD '${secrets.matrix_authentication_service_postgres_password}';
  CREATE DATABASE mas;
  GRANT ALL PRIVILEGES ON DATABASE mas TO mas;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname synapse <<-EOSQL
  GRANT ALL ON SCHEMA public TO synapse;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname mas <<-EOSQL
  GRANT ALL ON SCHEMA public TO mas;
EOSQL
