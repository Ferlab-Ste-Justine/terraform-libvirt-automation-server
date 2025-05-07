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

variable "libvirt_networks" {
  description = "Parameters of libvirt network connections if a libvirt networks are used."
  type = list(object({
    network_name = optional(string, "")
    network_id = optional(string, "")
    prefix_length = string
    ip = string
    mac = string
    gateway = optional(string, "")
    dns_servers = optional(list(string), [])
  }))
  default = []
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces."
  type        = list(object({
    interface     = string
    prefix_length = string
    ip            = string
    mac           = string
    gateway       = optional(string, "")
    dns_servers   = optional(list(string), [])
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
        certificate = optional(string, "")
        key = optional(string, "")
        username = optional(string, "")
        password = optional(string, "")
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
    })
    sync_directory = string
  })
}

variable "systemd_remote_source" {
  description = "Parameters for systemd-remote source service."
  type        = object({
    source = string
    etcd = optional(object({
      key_prefix = string
      endpoints = list(string)
      ca_certificate = string
      client = object({
        certificate = optional(string, "")
        key = optional(string, "")
        username = optional(string, "")
        password = optional(string, "")
      })
    }), {
      key_prefix = ""
      endpoints = []
      ca_certificate = ""
      client = {
        certificate = ""
        key = ""
        username = ""
        password = ""
      }
    })
    git = optional(object({
      repo = string
      ref  = string
      path = string
      auth = object({
        client_ssh_key         = string
        server_ssh_fingerprint = string
        client_ssh_user        = optional(string, "")
      })
      trusted_gpg_keys = optional(list(string), [])
    }), {
      repo = ""
      ref  = ""
      path = ""
      auth = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
        client_ssh_user        = ""
      }
      trusted_gpg_keys = []
    })
  })

  validation {
    condition     = contains(["etcd", "git"], var.systemd_remote_source.source)
    error_message = "systemd_remote_source.source must be 'etcd' or 'git'."
  }
}

variable "pushgateway" {
  description = "Parameters for prometheus pushgateway service."
  type        = object({
    enabled = bool
    server  = object({
      tls = object({
        ca_cert     = string
        server_cert = string
        server_key  = string
      })
      basic_auth = optional(object({
        username        = string
        hashed_password = string
      }), {
        username        = ""
        hashed_password = ""
      })
    })
    client  = object({
      tls = object({
        ca_cert     = string
        client_cert = string
        client_key  = string
      })
      basic_auth = optional(object({
        username = string
        password = string
      }), {
        username = ""
        password = ""
      })
    })
  })
  default = {
    enabled = false
    server = {
      tls = {
        ca_cert = ""
        server_cert = ""
        server_key = ""
      }
      basic_auth = {
        username = ""
        hashed_password = ""
      }
    }
    client = {
      tls = {
        ca_cert = ""
        client_cert = ""
        client_key = ""
      }
      basic_auth = {
        username = ""
        password = ""
      }
    }
  }
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
    metrics = optional(object({
      enabled = bool
      port    = number
    }), {
      enabled = false
      port    = 0
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
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
  }
}

variable "fluentbit_dynamic_config" {
  description = "Parameters for fluent-bit dynamic config if it is enabled"
  type = object({
    enabled = bool
    source  = string
    etcd    = optional(object({
      key_prefix     = string
      endpoints      = list(string)
      ca_certificate = string
      client         = object({
        certificate = optional(string, "")
        key         = optional(string, "")
        username    = optional(string, "")
        password    = optional(string, "")
      })
    }), {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
    })
    git     = optional(object({
      repo             = string
      ref              = string
      path             = string
      trusted_gpg_keys = optional(list(string), [])
      auth             = object({
        client_ssh_key         = string
        server_ssh_fingerprint = string
        client_ssh_user        = optional(string, "")
      })
    }), {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
        client_ssh_user        = ""
      }
    })
  })
  default = {
    enabled = false
    source = "etcd"
    etcd = {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
    }
    git  = {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
        client_ssh_user        = ""
      }
    }
  }

  validation {
    condition     = contains(["etcd", "git"], var.fluentbit_dynamic_config.source)
    error_message = "fluentbit_dynamic_config.source must be 'etcd' or 'git'."
  }
}