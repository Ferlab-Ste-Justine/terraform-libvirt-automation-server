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
      ${indent(6, systemd_remote.ca_certificate)}
  - path: /etc/systemd-remote/tls/service.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, systemd_remote.service_certificate)}
  - path: /etc/systemd-remote/tls/service.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, systemd_remote.service_key)}
  - path: /etc/systemd-remote/config.yml
    owner: root:root
    permissions: "0400"
    content: |
      units_config_path: units.yml
      server:
        port: ${systemd_remote.port}
        address: "${systemd_remote.address}"
        tls:
          ca_cert: /etc/systemd-remote/tls/ca.crt
          server_cert: /etc/systemd-remote/tls/service.crt
          server_key: /etc/systemd-remote/tls/service.key
#configuration-auto-updater
  - path: /etc/configurations-auto-updater/etcd/ca.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, etcd.ca_certificate)}
%{ if etcd.client.certificate != "" ~}
  - path: /etc/configurations-auto-updater/etcd/client.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, etcd.client.certificate)}
  - path: /etc/configurations-auto-updater/etcd/client.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, etcd.client.key)}
%{ else ~}
  - path: /etc/configurations-auto-updater/etcd/password.yml
    owner: root:root
    permissions: "0400"
    content: |
      username: ${etcd.client.username}
      password: ${etcd.client.password}
%{ endif ~}
  - path: /etc/configurations-auto-updater/config.yml
    owner: root:root
    permissions: "0400"
    content: |
      filesystem:
        path: "/opt/dynamic-configurations"
        files_permission: "600"
        directories_permission: 600"
      etcd_client:
        prefix: "${etcd.key_prefix}"
        endpoints:
%{ for endpoint in etcd.endpoints ~}
          - "${endpoint}"
%{ endfor ~}
        connection_timeout: "60s"
        request_timeout: "60s"
        retry_interval: "4s"
        retries: 15
        auth:
          ca_cert: "/etc/configurations-auto-updater/etcd/ca.crt"
%{ if etcd.client.certificate != "" ~}
          client_cert: "/etc/configurations-auto-updater/etcd/client.crt"
          client_key: "/etc/configurations-auto-updater/etcd/client.key"
%{ else ~}
          password_auth: /etc/configurations-auto-updater/etcd/password.yml
%{ endif ~}
      grpc_notifications:
        - endpoint: "${systemd_remote.address}:${systemd_remote.port}"
          filter: "^(.*[.]service)|(.*[.]timer)|units.yml)$"
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
#bootstrap configs
%{ for config in bootstrap_configs ~}
  - path: ${config.path}
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, config.value)}
%{ endfor ~}
#bootstrap secrets
%{ for secret in bootstrap_secrets ~}
  - path: ${secret.path}
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, secret.value)}
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
  - curl -L https://github.com/Ferlab-Ste-Justine/terracd/releases/download/v0.11.3/terracd-linux-amd64.zip -o /tmp/terracd.zip
  - unzip /tmp/terracd.zip
  - mv linux-amd64/terracd /usr/local/bin/terracd
  - rm -r linux-amd64
  #Install configurations-auto-updater
  - curl -L http://http://${host_ip}:9999/configurations-auto-updater /usr/local/bin/configurations-auto-updater
  - chmod +x /usr/local/bin/configurations-auto-updater
  #Install systemd-remote
  - curl -L http://http://${host_ip}:9999/systemd-remote /usr/local/bin/systemd-remote
  - chmod +x /usr/local/bin/systemd-remote
%{ endif ~}
  - systemctl enable configurations-auto-updater
  - systemctl start configurations-auto-updater
  - systemctl enable systemd-remote
  - systemctl start systemd-remote
%{ for service in bootstrap_services ~}
  - systemctl enable ${service}
  - systemctl start ${service}
%{ endfor ~}