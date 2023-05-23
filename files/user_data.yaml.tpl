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
%{ endif ~}
%{ for service in bootstrap_services ~}
  - systemctl enable ${service}
  - systemctl start ${service}
%{ endfor ~}