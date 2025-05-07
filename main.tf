locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_interfaces = concat(
    [for libvirt_network in var.libvirt_networks: {
      network_name = libvirt_network.network_name != "" ? libvirt_network.network_name : null
      network_id = libvirt_network.network_id != "" ? libvirt_network.network_id : null
      macvtap = null
      addresses = null
      mac = libvirt_network.mac
      hostname = null
    }],
    [for macvtap_interface in var.macvtap_interfaces: {
      network_name = null
      network_id = null
      macvtap = macvtap_interface.interface
      addresses = null
      mac = macvtap_interface.mac
      hostname = null
    }]
  )
  fluentbit_updater_etcd = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "etcd"
  fluentbit_updater_git = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "git"
}

module "network_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//network?ref=v0.37.4"
  network_interfaces = concat(
    [for idx, libvirt_network in var.libvirt_networks: {
      ip = libvirt_network.ip
      gateway = libvirt_network.gateway
      prefix_length = libvirt_network.prefix_length
      interface = "libvirt${idx}"
      mac = libvirt_network.mac
      dns_servers = libvirt_network.dns_servers
    }],
    [for idx, macvtap_interface in var.macvtap_interfaces: {
      ip = macvtap_interface.ip
      gateway = macvtap_interface.gateway
      prefix_length = macvtap_interface.prefix_length
      interface = "macvtap${idx}"
      mac = macvtap_interface.mac
      dns_servers = macvtap_interface.dns_servers
    }]
  )
}

module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.35.0"
  install_dependencies = var.install_dependencies
}

module "fluentbit_updater_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.37.4"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.fluentbit_dynamic_config.etcd.key_prefix
    endpoints = var.fluentbit_dynamic_config.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.fluentbit_dynamic_config.etcd.ca_certificate
      client_certificate = var.fluentbit_dynamic_config.etcd.client.certificate
      client_key = var.fluentbit_dynamic_config.etcd.client.key
      username = var.fluentbit_dynamic_config.etcd.client.username
      password = var.fluentbit_dynamic_config.etcd.client.password
    }
  }
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_updater_git_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//gitsync?ref=v0.37.4"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  git = var.fluentbit_dynamic_config.git
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=v0.37.4"
  install_dependencies = var.install_dependencies
  fluentbit = {
    metrics = var.fluentbit.metrics
    systemd_services = concat(
      [{
        tag = var.fluentbit.systemd_remote_source_tag
        service = "systemd-remote-source.service"
      },
      {
        tag = var.fluentbit.systemd_remote_tag
        service = "systemd-remote.service"
      },
      {
        tag = var.fluentbit.node_exporter_tag
        service = "node-exporter.service"
      }],
      var.terraform_backend_etcd.enabled ? [{
        tag = var.fluentbit.terraform_backend_etcd_tag
        service = "terraform-backend-etcd.service"
      }] : []
    )
    forward = var.fluentbit.forward
  }
  dynamic_config = {
    enabled = var.fluentbit_dynamic_config.enabled
    entrypoint_path = "/etc/fluent-bit-customization/dynamic-config/index.conf"
  }
}

module "systemd_remote_source_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.37.4"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = var.systemd_remote.sync_directory
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.systemd_remote_source.etcd.key_prefix
    endpoints = var.systemd_remote_source.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.systemd_remote_source.etcd.ca_certificate
      client_certificate = var.systemd_remote_source.etcd.client.certificate
      client_key = var.systemd_remote_source.etcd.client.key
      username = var.systemd_remote_source.etcd.client.username
      password = var.systemd_remote_source.etcd.client.password
    }
  }
  grpc_notifications = [{
    endpoint = "${var.systemd_remote.server.address}:${var.systemd_remote.server.port}"
    filter   = "^(.*[.]service)|(.*[.]timer)|(units.yml)$"
    trim_key_path = true
    max_chunk_size = 1048576
    retries = 15
    retry_interval = "4s"
    connection_timeout = "60s"
    request_timeout = "60s"
    auth = {
      ca_cert = var.systemd_remote.client.tls.ca_certificate
      client_cert = var.systemd_remote.client.tls.client_certificate
      client_key = var.systemd_remote.client.tls.client_key
    }
  }]
  naming = {
    binary = "systemd-remote-source"
    service = "systemd-remote-source"
  }
  user = "root"
}

module "systemd_remote_source_git_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//gitsync?ref=v0.37.4"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = var.systemd_remote.sync_directory
    files_permission = "700"
    directories_permission = "700"
  }
  git = var.systemd_remote_source.git
  grpc_notifications = [{
    endpoint = "${var.systemd_remote.server.address}:${var.systemd_remote.server.port}"
    filter   = "^(.*[.]service)|(.*[.]timer)|(units.yml)$"
    trim_key_path = true
    max_chunk_size = 1048576
    retries = 15
    retry_interval = "4s"
    connection_timeout = "60s"
    request_timeout = "60s"
    auth = {
      ca_cert = var.systemd_remote.client.tls.ca_certificate
      client_cert = var.systemd_remote.client.tls.client_certificate
      client_key = var.systemd_remote.client.tls.client_key
    }
  }]
  naming = {
    binary = "systemd-remote-source"
    service = "systemd-remote-source"
  }
  user = "root"
}

module "systemd_remote_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//systemd-remote?ref=v0.37.4"
  server = var.systemd_remote.server
  install_dependencies = var.install_dependencies
}

module "terraform_backend_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//terraform-backend-etcd?ref=v0.37.4"
  server = var.terraform_backend_etcd.server
  etcd = var.terraform_backend_etcd.etcd
  install_dependencies = var.install_dependencies
}

module "pushgateway_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//pushgateway?ref=v0.37.4"
  pushgateway = var.pushgateway.server
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.37.4"
  install_dependencies = var.install_dependencies
  chrony = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

locals {
  cloudinit_templates = concat([
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname = var.name
            ssh_admin_public_key = var.ssh_admin_public_key
            ssh_admin_user = var.ssh_admin_user
            admin_user_password = var.admin_user_password
            bootstrap_secrets = var.bootstrap_secrets
            bootstrap_configs = var.bootstrap_configs
            bootstrap_services = var.bootstrap_services
            pushgateway_client = var.pushgateway.client
            install_dependencies = var.install_dependencies
          }
        )
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      },
      {
        filename     = "system_remote.cfg"
        content_type = "text/cloud-config"
        content      = module.systemd_remote_configs.configuration
      }
    ],
    var.systemd_remote_source.source == "etcd" ? [{
      filename     = "system_remote_source.cfg"
      content_type = "text/cloud-config"
      content      = module.systemd_remote_source_etcd_configs.configuration
    }]: [],
    var.systemd_remote_source.source == "git" ? [{
      filename     = "system_remote_source.cfg"
      content_type = "text/cloud-config"
      content      = module.systemd_remote_source_git_configs.configuration
    }]: [],
    var.terraform_backend_etcd.enabled ? [{
      filename     = "terraform_backend_etcd.cfg"
      content_type = "text/cloud-config"
      content      = module.terraform_backend_etcd_configs.configuration
    }] : [],
    var.pushgateway.enabled ? [{
      filename     = "pushgateway.cfg"
      content_type = "text/cloud-config"
      content      = module.pushgateway_configs.configuration
    }] : [],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    local.fluentbit_updater_etcd ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_etcd_configs.configuration
    }] : [],
    local.fluentbit_updater_git ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_git_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : []
  )
}

data "template_cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "libvirt_cloudinit_disk" "automation_bootstrap" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = module.network_configs.configuration
  pool           = var.cloud_init_volume_pool
}

resource "libvirt_domain" "automation_bootstrap" {
  name = var.name

  cpu {
    mode = "host-passthrough"
  }

  vcpu = var.vcpus
  memory = var.memory

  disk {
    volume_id = var.volume_id
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id = network_interface.value["network_id"]
      network_name = network_interface.value["network_name"]
      macvtap = network_interface.value["macvtap"]
      addresses = network_interface.value["addresses"]
      mac = network_interface.value["mac"]
      hostname = network_interface.value["hostname"]
    }
  }

  autostart = true

  cloudinit = libvirt_cloudinit_disk.automation_bootstrap.id

  //https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf#L61
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}