set -e

LOG=${LOG:-/root/stackscript.log}

# Install basic requirements of this stackscript
function install-requirements {
  apt-get update >$LOG 2>&1
  apt-get upgrade -y >$LOG 2>&1
  apt-get install -y curl jq >$LOG 2>&1
}

# Make an API call
#
# Arguments: APIAction LinodeID
# Assumed vars:
#   APIKEY
#
# Returns via echo: json response
function api-call {
  curl "https://api.linode.com/?api_key=$APIKEY&api_action=$1&linodeid=$2" 2>$LOG | tee $LOG
}

# Add a private IP to this linode
#
# Assumed vars:
#   APIKEY
#   LINODE_ID
function ensure-private-ip {
  api-call "linode.ip.addprivate" "$LINODE_ID" >/dev/null
  echo "Added private ip to node" | tee $LOG
}

# Retrieve IP and label information from API
#
# Arguments: LinodeID
#
# Assumed vars:
#   APIKEY
#
# Vars set:
#   PUBLIC_IP
#   PRIVATE_IP
#   LABEL
function get-api-data {
  local ipresp=$(api-call "linode.ip.list" "$1")
  local listresp=$(api-call "linode.list" "$1")

  PUBLIC_IP=$(echo $ipresp | jq '.DATA[] | select(.ISPUBLIC == 1) | .IPADDRESS' | head -1 | xargs)
  PRIVATE_IP=$(echo $ipresp | jq '.DATA[] | select(.ISPUBLIC == 0) | .IPADDRESS' | head -1 | xargs)
  LABEL=$(echo $listresp | jq '.DATA[0].LABEL' | xargs)

  echo "Got API Info ($1): ${LABEL} / Public IP: ${PUBLIC_IP} / Private IP: ${PRIVATE_IP}" | tee $LOG

  if [[ -z $LABEL ]]; then
    echo "Failed to get label from $1!" | tee $LOG
    exit 2
  fi
}

# Retrieve my IP and label information from API
#
# Assumed vars:
#   APIKEY
#   LINODE_ID
#
# Vars set:
#   MY_PUBLIC_IP
#   MY_PRIVATE_IP
#   MY_LABEL
function get-my-api-data {
  get-api-data $LINODE_ID

  MY_PUBLIC_IP=$PUBLIC_IP
  MY_PRIVATE_IP=$PRIVATE_IP
  MY_LABEL=$LABEL
}

# Setup /etc/hostname and hostname with label
#
# Assumed vars:
#   LABEL
function setup-hostname {
  echo $LABEL > /etc/hostname
  hostname -F /etc/hostname
  echo "Set hostname: ${LABEL}"
}

# Setup /etc/hosts with ourself
#
# Assumed vars:
#   DOTDOMAIN
#   MY_PRIVATE_IP
#   MY_LABEL
function setup-my-etc-hosts {
  local line="${MY_PRIVATE_IP} ${MY_LABEL}"
  if [[ ! -z $DOTDOMAIN ]]; then line="${line} ${MY_LABEL}${DOTDOMAIN}"; fi

  cat <<EOF >>/etc/hosts
$line
EOF
  echo "Added to /etc/hosts: ${line}" | tee $LOG
}


# Setup private networking for this linode
#
# Assumed Vars:
#  MY_PUBLIC_IP
#  MY_PRIVATE_IP
function setup-networking {
  local my_public_gateway="$(echo $MY_PUBLIC_IP | cut -d'.' -f1-3).1"

  cat <<EOF >/etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
  address ${MY_PUBLIC_IP}/24
  gateway ${my_public_gateway}

iface eth0 inet static
  address ${MY_PRIVATE_IP}/17
EOF

  ifdown -a >$LOG 2>&1 && \
  ifup -a >$LOG 2>&1 && \
  echo 'Networking setup complete!' | tee $LOG || \
  (echo "Failed to start networking" | tee $LOG; exit 2)
}

# install saltstack
# Argument: "master" or nothing
function install-saltstack {
  curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh >$LOG 2>&1
  if [[ $1 == "master" ]]; then
    sh /tmp/install_salt.sh -M git $SALTVERSION >$LOG 2>&1
  else
    sh /tmp/install_salt.sh git $SALTVERSION >$LOG 2>&1
  fi

  echo "Saltstack installed!"
}

# Call the various basic setup functions
function basic-setup {
  install-requirements
  ensure-private-ip
  get-my-api-data
  setup-hostname
  setup-my-etc-hosts
  setup-networking
}

## Call our main function
main