#!/bin/bash
# This block defines the variables the user of the script needs to input
# when deploying using this script.
#
#<UDF name="domain" label="The new Linode's Domain Name">
#<UDF name="saltversion" label="The saltstack version" default="v2015.5.5">
#<UDF name="apikey" label="The Linode api key">
#<UDF name="master_id" label="The linode ID of the salt-master">

function main {
  validate-inputs
  basic-setup
  get-master-api-data
  setup-master-etc-hosts
  install-saltstack
  configure-salt-minion
  echo 'All done!' | tee $LOG
}

function validate-inputs {
  if [[ ! -z $DOMAIN ]]; then DOTDOMAIN=".$DOMAIN"; else DOTDOMAIN=""; fi
  if [[ -z $SALTVERSION ]]; then SALTVERSION="v2015.5.5"; fi
  if [[ -z $MASTER_ID ]]; then
    echo "WARNING: No master label given. I won't set that in /etc/salt/minion then"  | tee $LOG
  fi
  if [[ -z $APIKEY ]]; then
    echo "ERROR: No API Key! I need this." | tee $LOG
    exit 2
  fi
  echo "Inputs:"  | tee $LOG
  echo "Linode ID: $LINODE_ID"  | tee $LOG
  echo "Domain: $DOTDOMAIN" | tee $LOG
  echo "Salt Version: $SALTVERSION" | tee $LOG
  echo "Master ID: $MASTER_ID" | tee $LOG
  echo "API Key: $APIKEY" | tee $LOG
}

# Retrieve Master's IP and label information from API
#
# Assumed vars:
#   APIKEY
#   MASTER_ID
#
# Vars set:
#   MASTER_PUBLIC_IP
#   MASTER_PRIVATE_IP
#   MASTER_LABEL
function get-master-api-data {
  get-api-data $MASTER_ID

  MASTER_PUBLIC_IP=$PUBLIC_IP
  MASTER_PRIVATE_IP=$PRIVATE_IP
  MASTER_LABEL=$LABEL
}

# Setup /etc/hosts with master
#
# Assumed vars:
#   DOTDOMAIN
#   MASTER_PRIVATE_IP
#   MASTER_LABEL
function setup-master-etc-hosts {
  local line="${MASTER_PRIVATE_IP} ${MASTER_LABEL}"
  if [[ ! -z $DOTDOMAIN ]]; then line="${line} ${MASTER_LABEL}${DOTDOMAIN}"; fi

  cat <<EOF >>/etc/hosts
$line
EOF
  echo "Added to /etc/hosts: ${line}" | tee $LOG
}

function configure-salt-minion {
  cat <<EOF >/etc/salt/minion
master: $MASTER_LABEL
id: $MY_LABEL
EOF

  mkdir -p /etc/salt/minion.d
  cat <<EOF >/etc/salt/minion.d/grains.conf
grains:
  roles:
    - kubernetes-pool
  cloud: linode
  network_mode: flannel
  etcd_servers: http://$MASTER_LABEL:4001
  api_servers: $MASTER_LABEL
EOF

  salt-key --gen-keys=minion --gen-keys-dir=/etc/salt/pki/minion >$LOG 2>&1
  service salt-minion restart  >$LOG 2>&1
  echo 'Salt minion configured' | tee $LOG
}