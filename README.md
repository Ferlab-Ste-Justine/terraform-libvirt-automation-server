# About

This terraform module is used to provision an automation server running terraform workflows that is easily editable via etcd configurations.

It is meant to be espescially useful in an on-prem setup where you start with very little and would prefer to minimize the number of terraform workflows you need to manage by hand (to ideally just this server and only when bootstrapping automation, if etcd is down or when performing routine updates on the automation server).

It has two kinds of workflows:
  - Static jobs defined via cloud-init that can be used to bootstrap (and change by reprovisioning the server) the etcd cluster that the server will take its configurations from. Note that these jobs maybe be overwriten dynamically once you have a running etcd cluster that you can read dynamic configurations from.
  - Dynamic workflows defined in etcd. Systemd unit files, units on/off status, other dependent configuration files as well as optional fluent-bit output redirection are editable this way.

The server has the following tools integrated to support terraform jobs:
- terraform: https://www.terraform.io/
- terracd: https://github.com/Ferlab-Ste-Justine/terracd
- terraform-backend-etcd (optional): https://github.com/Ferlab-Ste-Justine/terraform-backend-etcd

# Usage

## Inputs

...

## Dynamic Configuration Worflow

...

## Dependency Considerations

...