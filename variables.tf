variable "name" {
  description = "Name to give to the vm."
  type        = string
}

variable "vcpus" {
  description = "Number of vcpus to assign to the vm"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in MiB"
  type        = number
  default     = 8192
}

variable "volume_id" {
  description = "Id of the disk volume to attach to the vm"
  type        = string
}

variable "libvirt_network" {
  description = "Parameters of the libvirt network connection if a libvirt network is used. Has the following parameters: network_id, network_name, ip, mac"
  type = object({
    network_name = string
    network_id = string
    ip = string
    mac = string
    dns_servers = list(string)
  })
  default = {
    network_name = ""
    network_id = ""
    ip = ""
    mac = ""
    dns_servers = []
  }
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces. Mutually exclusive with the network_id, ip and mac fields. Each entry has the following keys: interface, prefix_length, ip, mac, gateway and dns_servers"
  type        = list(object({
    interface = string,
    prefix_length = number,
    ip = string,
    mac = string,
    gateway = string,
    dns_servers = list(string),
  }))
  default = []
}

variable "cloud_init_volume_pool" {
  description = "Name of the volume pool that will contain the cloud init volume"
  type        = string
}

variable "cloud_init_volume_name" {
  description = "Name of the cloud init volume"
  type        = string
  default = ""
}

variable "ssh_admin_user" { 
  description = "Pre-existing ssh admin user of the image"
  type        = string
  default     = "ubuntu"
}

variable "admin_user_password" { 
  description = "Optional password for admin user"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_admin_public_key" {
  description = "Public ssh part of the ssh key the admin will be able to login as"
  type        = string
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools = []
    makestep = {
      threshold = 0,
      limit = 0
    }
  }
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type = bool
  default = true
}

variable "terraform_backend_etcd" {
  description = "Optional terraform backend service using etcd as a backend"
  type        = object({
    enabled = bool
    server = object({
      port = number
      address = string
      tls = object({
        ca_certificate = string
        server_certificate = string
        server_key = string
      })
      auth = object({
        username = string
        password = string
      })
    })
    etcd = object({
      endpoints = list(string)
      ca_certificate = string
      client = object({
        certificate = string
        key = string
        username = string
        password = string
      })
    })
  })
  default = {
    enabled = false
    server = {
      port = 0
      address = ""
      tls = {
        ca_certificate = ""
        server_certificate = ""
        server_key = ""
      }
      auth = {
        username = ""
        password = ""
      }
    }
    etcd = {
      key_prefix = ""
      endpoints = []
      ca_certificate = ""
      client = {
        certificate = ""
        key = ""
        username = ""
        password = ""
      }
    }
  }
}

variable "systemd_remote" {
  description = "Parameters for systemd-remote service. Certs are used by client and server for mtls communication"
  type        = object({
    server = object({
      port = number
      address = string
      tls = object({
        ca_certificate = string
        server_certificate = string
        server_key = string
      })
    })
    client = object({
      tls = object({
        ca_certificate     = string
        client_certificate = string
        client_key         = string
      })
      etcd = object({
        key_prefix = string
        endpoints = list(string)
        ca_certificate = string
        client = object({
          certificate = string
          key = string
          username = string
          password = string
        })
      })
    })
    sync_directory = string
  })
}

variable "bootstrap_secrets" {
  description = "Secrets that boostrap the orchestration"
  sensitive = true
  type = list(object({
    path  = string
    content = string
  }))
  default = []
}

variable "bootstrap_configs" {
  description = "Configs to bootstrap the orchestration"
  type = list(object({
    path  = string
    content = string
  }))
  default = []
}

variable "bootstrap_services" {
  description = "Systemd services to enable and start"
  type = list(string)
    default = []
}

variable "fluentbit" {
  description = "Fluent-bit configuration"
  type = object({
    enabled = bool
    systemd_remote_source_tag = string
    systemd_remote_tag = string
    terraform_backend_etcd_tag = string
    node_exporter_tag = string
    metrics = object({
      enabled = bool
      port    = number
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
    })
    etcd = object({
      enabled = bool
      key_prefix = string
      endpoints = list(string)
      ca_certificate = string
      client = object({
        certificate = string
        key = string
        username = string
        password = string
      })
    })
  })
  default = {
    enabled = false
    systemd_remote_source_tag = ""
    systemd_remote_tag = ""
    terraform_backend_etcd_tag = ""
    node_exporter_tag = ""
    metrics = {
      enabled = false
      port = 0
    }
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
    etcd = {
      enabled = false
      key_prefix = ""
      endpoints = []
      ca_certificate = ""
      client = {
        certificate = ""
        key = ""
        username = ""
        password = ""
      }
    }
  }
}