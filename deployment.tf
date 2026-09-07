locals {
  firewall_config = file("${path.module}/butane/nftables.nft")

  # A pod is one restart group: all members share namespaces and must be
  # restarted together when a member or its mounted configuration changes.
  quadlet_containers = {
    for path, content in local.config_files : trimsuffix(basename(path), ".container") => {
      path    = path
      content = content
      pod     = try(regex("(?m)^Pod=([^\\r\\n]+)", content)[0], null)
      mounts  = flatten(regexall("(?m)^Volume=%E/([^:\\r\\n]+)", content))
    } if endswith(path, ".container")
  }
  quadlet_pods = {
    for path, content in local.config_files : basename(path) => path if endswith(path, ".pod")
  }
  container_groups = {
    for name, container in local.quadlet_containers :
    (container.pod == null ? "${name}.service" : "${trimsuffix(container.pod, ".pod")}-pod.service") => name...
  }
  common_quadlet_paths = [
    for path in keys(local.config_files) : path
    if startswith(path, "containers/systemd/") && (
      endswith(path, ".network") || endswith(path, ".volume") || endswith(path, ".conf")
    )
  ]
  container_group_paths = {
    for group, members in local.container_groups : group => distinct(concat(
      local.common_quadlet_paths,
      [for member in members : local.quadlet_containers[member].path],
      [for member in members : local.quadlet_pods[local.quadlet_containers[member].pod] if local.quadlet_containers[member].pod != null],
      flatten([for member in members : [
        for path in keys(local.config_files) : path if anytrue([
          for mount in local.quadlet_containers[member].mounts : path == mount || startswith(path, "${mount}/")
        ])
      ]])
    ))
  }
  deployment_groups = merge(
    {
      for group, members in local.container_groups : group => {
        units  = distinct(concat([group], [for member in members : "${member}.service"]))
        enable = []
        hash = sha256(jsonencode({
          for path in local.container_group_paths[group] : path => local.config_files[path]
        }))
        uses_secrets = anytrue([for member in members : can(regex("(?m)^Secret=", local.quadlet_containers[member].content))])
      }
    },
    {
      for path, content in local.config_files : basename(path) => {
        units  = [basename(path)]
        enable = [basename(path)]
        hash = sha256(jsonencode({
          timer   = content
          service = local.config_files["${trimsuffix(path, ".timer")}.service"]
        }))
        uses_secrets = false
      } if startswith(path, "systemd/user/") && endswith(path, ".timer")
    }
  )

  managed_units = distinct(concat(
    flatten([for group in local.deployment_groups : group.units]),
    [for path in keys(local.config_files) : basename(path) if startswith(path, "systemd/user/") && endswith(path, ".service")],
    [for path in keys(local.config_files) : "${trimsuffix(basename(path), ".network")}-network.service" if endswith(path, ".network")],
    [for path in keys(local.config_files) : "${trimsuffix(basename(path), ".volume")}-volume.service" if endswith(path, ".volume")]
  ))
}
