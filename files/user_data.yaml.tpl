#cloud-config
merge_how:
 - name: list
   settings: [append, no_replace]
 - name: dict
   settings: [no_replace, recurse_list]

%{ if admin_user_password != "" ~}
ssh_pwauth: false
chpasswd:
  expire: False
  users:
    - name: ${ssh_admin_user}
      password: "${admin_user_password}"
      type: text
%{ endif ~}
preserve_hostname: false
hostname: ${hostname}
users:
  - default
  - name: ${ssh_admin_user}
    ssh_authorized_keys:
      - "${ssh_admin_public_key}"

write_files:
#systemd-remote
  - path: /etc/systemd-remote/tls/ca.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, systemd_remote.tls.ca_certificate)}
  - path: /etc/systemd-remote/tls/service.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, systemd_remote.tls.server_certificate)}
  - path: /etc/systemd-remote/tls/service.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, systemd_remote.tls.server_key)}
  - path: /etc/systemd-remote/config.yml
    owner: root:root
    permissions: "0400"
    content: |
      units_config_path: /etc/systemd-remote/units.yml
      server:
        port: ${systemd_remote.port}
        address: "${systemd_remote.address}"
        tls:
          ca_cert: /etc/systemd-remote/tls/ca.crt
          server_cert: /etc/systemd-remote/tls/service.crt
          server_key: /etc/systemd-remote/tls/service.key
  - path: /etc/systemd/system/systemd-remote.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="Systemd Remote Update Service"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      Environment=SYSTEMD_REMOTE_CONFIG_FILE=/etc/systemd-remote/config.yml
      User=root
      Group=root
      Type=simple
      Restart=always
      RestartSec=1
      WorkingDirectory=/opt/dynamic-configurations
      ExecStart=/usr/local/bin/systemd-remote

      [Install]
      WantedBy=multi-user.target
#configuration-auto-updater
  - path: /etc/configurations-auto-updater/etcd/ca.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, configurations_auto_updater.etcd.ca_certificate)}
%{ if configurations_auto_updater.etcd.client.certificate != "" ~}
  - path: /etc/configurations-auto-updater/etcd/client.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, configurations_auto_updater.etcd.client.certificate)}
  - path: /etc/configurations-auto-updater/etcd/client.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, configurations_auto_updater.etcd.client.key)}
%{ else ~}
  - path: /etc/configurations-auto-updater/etcd/password.yml
    owner: root:root
    permissions: "0400"
    content: |
      username: ${configurations_auto_updater.etcd.client.username}
      password: ${configurations_auto_updater.etcd.client.password}
%{ endif ~}
  - path: /etc/configurations-auto-updater/config.yml
    owner: root:root
    permissions: "0400"
    content: |
      filesystem:
        path: "/opt/dynamic-configurations"
        files_permission: "700"
        directories_permission: "700"
      etcd_client:
        prefix: "${configurations_auto_updater.etcd.key_prefix}"
        endpoints:
%{ for endpoint in configurations_auto_updater.etcd.endpoints ~}
          - "${endpoint}"
%{ endfor ~}
        connection_timeout: "60s"
        request_timeout: "60s"
        retry_interval: "4s"
        retries: 15
        auth:
          ca_cert: "/etc/configurations-auto-updater/etcd/ca.crt"
%{ if configurations_auto_updater.etcd.client.certificate != "" ~}
          client_cert: "/etc/configurations-auto-updater/etcd/client.crt"
          client_key: "/etc/configurations-auto-updater/etcd/client.key"
%{ else ~}
          password_auth: /etc/configurations-auto-updater/etcd/password.yml
%{ endif ~}
      grpc_notifications:
        - endpoint: "${systemd_remote.address}:${systemd_remote.port}"
          filter: "^(.*[.]service)|(.*[.]timer)|(units.yml)$"
          trim_key_path: true
          max_chunk_size: 1048576
          connection_timeout: "60s"
          request_timeout: "60s"
          retry_interval: "4s"
          retries: 15
          auth:
            ca_cert: "/etc/systemd-remote/tls/ca.crt"
            client_cert: "/etc/systemd-remote/tls/service.crt"
            client_key: "/etc/systemd-remote/tls/service.key"
  - path: /etc/systemd/system/configurations-auto-updater.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="Configurations Updating Service"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      Environment=CONFS_AUTO_UPDATER_CONFIG_FILE=/etc/configurations-auto-updater/config.yml
      User=root
      Group=root
      Type=simple
      Restart=always
      RestartSec=1
      WorkingDirectory=/opt/dynamic-configurations
      ExecStart=/usr/local/bin/configurations-auto-updater

      [Install]
      WantedBy=multi-user.target
#terraform-backend-etcd
%{ if terraform_backend_etcd.enabled ~}
  - path: /etc/terraform-backend-etcd/terraform/backend-vars
    owner: root:root
    permissions: "0400"
    content: |
      TF_HTTP_USERNAME=${terraform_backend_etcd.auth.username}
      TF_HTTP_PASSWORD=${terraform_backend_etcd.auth.password}
      TF_HTTP_UPDATE_METHOD=PUT
      TF_HTTP_LOCK_METHOD=PUT
      TF_HTTP_UNLOCK_METHOD=DELETE
  - path: /etc/terraform-backend-etcd/etcd/ca.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, terraform_backend_etcd.etcd.ca_certificate)}
%{ if terraform_backend_etcd.etcd.client.certificate != "" ~}
  - path: /etc/terraform-backend-etcd/etcd/client.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, terraform_backend_etcd.etcd.client.certificate)}
  - path: /etc/terraform-backend-etcd/etcd/client.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, terraform_backend_etcd.etcd.client.key)}
%{ else ~}
  - path: /etc/terraform-backend-etcd/etcd/password.yml
    owner: root:root
    permissions: "0400"
    content: |
      username: ${terraform_backend_etcd.etcd.client.username}
      password: ${terraform_backend_etcd.etcd.client.password}
%{ endif ~}
  - path: /etc/terraform-backend-etcd/tls/ca.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, terraform_backend_etcd.tls.ca_certificate)}
  - path: /etc/terraform-backend-etcd/tls/server.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, terraform_backend_etcd.tls.server_certificate)}
  - path: /etc/terraform-backend-etcd/tls/server.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, terraform_backend_etcd.tls.server_key)}
  - path: /etc/terraform-backend-etcd/auth.yml
    owner: root:root
    permissions: "0400"
    content: |
      ${terraform_backend_etcd.auth.username}: "${terraform_backend_etcd.auth.password}"
  - path: /etc/terraform-backend-etcd/config.yml
    owner: root:root
    permissions: "0400"
    content: |
      server:
        port: ${terraform_backend_etcd.port}
        address: "${terraform_backend_etcd.address}"
        basic_auth: /etc/terraform-backend-etcd/auth.yml
        tls:
          certificate: /etc/terraform-backend-etcd/tls/server.crt
          key: /etc/terraform-backend-etcd/tls/server.key
        debug_mode: false
      etcd_client:
        endpoints:
%{ for endpoint in terraform_backend_etcd.etcd.endpoints ~}
          - "${endpoint}"
%{ endfor ~}
        connection_timeout: "300s"
        request_timeout: "300s"
        retry_interval: "10s"
        retries: 30
        auth:
          ca_cert: "/etc/terraform-backend-etcd/etcd/ca.crt"
%{ if terraform_backend_etcd.etcd.client.certificate != "" ~}
          client_cert: "/etc/terraform-backend-etcd/etcd/client.crt"
          client_key: "/etc/terraform-backend-etcd/etcd/client.key"
%{ else ~}
          password_auth: /etc/terraform-backend-etcd/etcd/password.yml
%{ endif ~}
      remote_termination: false
  - path: /etc/systemd/system/terraform-backend-etcd.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="Terraform Backend Service"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      Environment=ETCD_BACKEND_CONFIG_FILE=/etc/terraform-backend-etcd/config.yml
      User=root
      Group=root
      Type=simple
      Restart=always
      RestartSec=1
      ExecStart=/usr/local/bin/terraform-backend-etcd

      [Install]
      WantedBy=multi-user.target
%{ endif ~}
#bootstrap configs
%{ for config in bootstrap_configs ~}
  - path: ${config.path}
    owner: root:root
    permissions: "0700"
    content: |
      ${indent(6, config.content)}
%{ endfor ~}
#bootstrap secrets
%{ for secret in bootstrap_secrets ~}
  - path: ${secret.path}
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, secret.content)}
%{ endfor ~}

%{ if install_dependencies ~}
packages:
  - curl
  - unzip
%{ endif ~}

runcmd:
%{ if install_dependencies ~}
  #Install terraform
  - curl -L https://releases.hashicorp.com/terraform/1.4.6/terraform_1.4.6_linux_amd64.zip -o /tmp/terraform.zip
  - unzip /tmp/terraform.zip
  - mv terraform /usr/local/bin/terraform
  - rm /tmp/terraform.zip
  #Install terracd
  - curl -L https://github.com/Ferlab-Ste-Justine/terracd/releases/download/v0.13.0/terracd-linux-amd64.zip -o /tmp/terracd.zip
  - unzip /tmp/terracd.zip
  - mv linux-amd64/terracd /usr/local/bin/terracd
  - rm -r linux-amd64
  #Install etcd terraform backend service
  - curl -L https://github.com/Ferlab-Ste-Justine/terraform-backend-etcd/releases/download/v0.4.0/terraform-backend-etcd_0.4.0_linux_amd64.tar.gz -o /tmp/terraform-backend-etcd.tar.gz
  - mkdir -p /tmp/terraform-backend-etcd
  - tar zxvf /tmp/terraform-backend-etcd.tar.gz -C /tmp/terraform-backend-etcd
  - cp /tmp/terraform-backend-etcd/terraform-backend-etcd /usr/local/bin/terraform-backend-etcd
  - rm /tmp/terraform-backend-etcd.tar.gz
  - rm -r /tmp/terraform-backend-etcd
  #Install configurations-auto-updater
  - curl -L https://github.com/Ferlab-Ste-Justine/configurations-auto-updater/releases/download/v0.4.0/configurations-auto-updater_0.4.0_linux_amd64.tar.gz -o /tmp/configurations-auto-updater_0.4.0_linux_amd64.tar.gz
  - mkdir -p /tmp/configurations-auto-updater
  - tar zxvf /tmp/configurations-auto-updater_0.4.0_linux_amd64.tar.gz -C /tmp/configurations-auto-updater
  - cp /tmp/configurations-auto-updater/configurations-auto-updater /usr/local/bin/configurations-auto-updater
  - rm -rf /tmp/configurations-auto-updater
  - rm -f /tmp/configurations-auto-updater_0.4.0_linux_amd64.tar.gz
  #Install systemd-remote
  - curl -L http://${host_ip}:9999/systemd-remote -o /usr/local/bin/systemd-remote
  - chmod +x /usr/local/bin/systemd-remote
%{ endif ~}
  - mkdir -p /opt/dynamic-configurations
  - systemctl enable configurations-auto-updater
  - systemctl start configurations-auto-updater
  - systemctl enable systemd-remote
  - systemctl start systemd-remote
%{ if terraform_backend_etcd.enabled ~}
  - cp /etc/terraform-backend-etcd/tls/ca.crt /usr/local/share/ca-certificates
  - update-ca-certificates
  - systemctl enable terraform-backend-etcd
  - systemctl start terraform-backend-etcd
%{ endif ~}
%{ for service in bootstrap_services ~}
  - systemctl enable ${service}
  - systemctl start ${service}
%{ endfor ~}