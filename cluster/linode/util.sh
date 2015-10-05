#!/bin/bash

# Copyright 2014 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A library of helper functions and constant for the local config.

# Use the config file specified in $KUBE_CONFIG_FILE, or default to
# config-default.sh.
KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/cluster/linode/${KUBE_CONFIG_FILE-"config-default.sh"}"
source "${KUBE_ROOT}/cluster/common.sh"

########## Required functions ###########

function detect-master {
  KUBE_MASTER=${MASTER_LABEL}
  if [[ -z "${KUBE_MASTER_IP-}" ]]; then
    KUBE_MASTER_IP=$(get_linode_ip ${KUBE_MASTER})
    KUBE_MASTER_PRIVATE_IP=$(get_linode_private_ip ${KUBE_MASTER})
  fi
  if [[ -z "${KUBE_MASTER_IP-}" ]]; then
    echo "Could not detect Kubernetes master node IP.  Make sure you've launched a cluster with 'kube-up.sh'"
    exit 1
  fi
  echo "Using master: $KUBE_MASTER (external IP: $KUBE_MASTER_IP)"
}

# Get minion names if they are not static.
function detect-minion-names {
  MINION_NAMES=$(get_minion_labels)
  echo "MINION_NAMES: ${MINION_NAMES[*]}"
}

# Get minion IP addresses and store in KUBE_MINION_IP_ADDRESSES[]
function detect-minions {
  KUBE_MINION_IP_ADDRESSES=$(get_minion_ips)

  if [[ -z "$KUBE_MINION_IP_ADDRESSES" ]]; then
    echo "Could not detect Kubernetes minion nodes.  Make sure you've launched a cluster with 'kube-up.sh'"
    exit 1
  fi
  echo "KUBE_MINION_IP_ADDRESSES: ${KUBE_MINION_IP_ADDRESSES[*]}"
}

# Verify prereqs on host machine
function verify-prereqs {
  if [[ "$(which linode)" == "" ]]; then
    echo "Can't find linode in PATH, please fix and retry. See https://github.com/linode/cli"
    exit 1
  fi
  if [[ "$(which jq)" == "" ]]; then
    echo "Can't find jq in PATH, please fix and retry. See https://github.com/stedolan/jq"
    exit 1
  fi
  if [[ -z "$(linode account show > /dev/null && echo 1)" ]]; then
    echo "linode cli is not configured. Do linode configure"
    exit 1
  fi
}

# Instantiate a kubernetes cluster
function kube-up {

  ## Resolve information
  resolve-distro
  resolve-api-key
  resolve-admin-user
  create-tokens

  ## Make the stackscripts
  ensure-stackscripts

  ## Create master
  create-master
  detect-master
  wait-for-master

  ## Create minions
  create-minions
  detect-minions
  wait-for-minions

  ## Wait for entire cluster to be up
  wait-for-master

  echo "Kubernetes cluster created."

  ## Verify cluster
  get-kubeconfig
  verify-cluster
}

# Delete a kubernetes cluster
function kube-down {
  resolve-api-key
  detect-master
  detect-minions

  echo "Deleting master $MASTER_LABEL"
  delete-master

  echo "Deleting minions: ${MINION_NAMES[@]}"
  delete-minions
}

# Update a kubernetes cluster
function kube-push {
  echo "TODO"
}

# Prepare update a kubernetes component
function prepare-push {
}

# Update a kubernetes master
function push-master {
  echo "TODO"
}

# Update a kubernetes node
function push-node {
  echo "TODO"
}

# Execute prior to running tests to build a release if required for env
function test-build-release {
  echo "TODO"
}

# Execute prior to running tests to initialize required structure
function test-setup {
  echo "TODO"
}

# Execute after running tests to perform any required clean-up
function test-teardown {
  echo "TODO"
}

# Set the {KUBE_USER} and {KUBE_PASSWORD} environment values required to interact with provider
function get-password {
  echo "TODO"
}


########## 1st level utilities ##############

function verify-cluster {
  local kubectl="${KUBE_ROOT}/cluster/kubectl.sh"
  readys=$($kubectl get nodes -ojson | jq '.items[] | select(.status.conditions | first | .type == "Ready") | .metadata.name | wc -l')
  if [[ $readys == $NUM_MINIONS ]]; then
    echo "Your cluster is fully ready!"
  else
    echo "Not all members of the cluster came up. Perhaps you should wait longer or just run kube_down.sh"
  fi
}

## Creating things

function create-master {
  create-linode --label "${MASTER_LABEL}" \
                --plan "linode${MASTER_SIZE}" \
                --stackscript "${MASTER_STACKSCRIPT}" \
                --stackscriptjson "{\"domain\":\"$LINODE_DOMAIN\",
                                    \"saltversion\":\"$SALT_VERSION\",
                                    \"apikey\":\"$LINODE_API_KEY\",
                                    \"server_binary_tar_url\":\"$SERVER_BINARY_TAR_URL\",
                                    \"salt_tar_url\":\"$SALT_TAR_URL\",
                                    \"instance_prefix\":\"$INSTANCE_PREFIX\",
                                    \"node_instance_prefix\":\"$MINION_LABEL\",
                                    \"service_cluster_ip_range\":\"$SERVICE_CLUSTER_IP_RANGE\",
                                    \"enable_cluster_monitoring\":\"$ENABLE_CLUSTER_MONITORING\",
                                    \"enable_cluster_logging\":\"$ENABLE_CLUSTER_LOGGING\",
                                    \"enable_node_logging\":\"$ENABLE_NODE_LOGGING\",
                                    \"logging_destination\":\"$LOGGING_DESTINATION\",
                                    \"elasticsearch_logging_replicas\":\"$ELASTICSEARCH_LOGGING_REPLICAS\",
                                    \"enable_cluster_dns\":\"$ENABLE_CLUSTER_DNS\",
                                    \"dns_replicas\":\"$DNS_REPLICAS\",
                                    \"dns_server_ip\":\"$DNS_SERVER_IP\",
                                    \"dns_domain\":\"$DNS_DOMAIN\",
                                    \"admission_control\":\"$ADMISSION_CONTROL\",
                                    \"kube_user\":\"$KUBE_USER\",
                                    \"kube_password\":\"$KUBE_PASSWORD\",
                                    \"kubelet_token\":\"$KUBELET_TOKEN\",
                                    \"kube_proxy_token\":\"$KUBE_PROXY_TOKEN\"}"
}

function create-minions {
  for (( i=1; i<=$NUM_MINIONS; i++ )); do
    create-linode --label "${MINION_LABEL}-${i}" \
                  --plan "linode${MINION_SIZE}" \
                  --stackscript "${MINION_STACKSCRIPT}" \
                  --stackscriptjson "{\"domain\":\"${LINODE_DOMAIN}\",
                                      \"saltversion\":\"${SALT_VERSION}\",
                                      \"apikey\":\"${LINODE_API_KEY}\",
                                      \"masterip\":\"${KUBE_MASTER_PRIVATE_IP}\",
                                      \"masterlabel\":\"${MASTER_LABEL}\"}"
  done
}

# Create a temp dir that'll be deleted at the end of this bash session.
#
# Vars set:
#   KUBE_TEMP
function ensure-temp-dir {
  if [[ -z ${KUBE_TEMP-} ]]; then
    KUBE_TEMP=$(mktemp -d -t kubernetes.XXXXXX)
    trap 'rm -rf "${KUBE_TEMP}"' EXIT
  fi
}

function delete-master {
  delete-linode ${MASTER_LABEL}
}

function delete-minions {
  for minion in $MINION_NAMES; do
    delete-linode $minion
  done
}

function ensure-stackscripts {
  ensure-temp-dir

  cat "$KUBE_ROOT/cluster/linode/templates/minion-header.sh" \
      "$KUBE_ROOT/cluster/linode/templates/common.sh" > \
      "$KUBE_TEMP/stackscript-minion.sh"

  MINION_STACKSCRIPT=$(ensure-stackscript "$KUBE_TEMP/stackscript-minion.sh" "kubernetes-minion")

  cat "$KUBE_ROOT/cluster/linode/templates/master-header.sh" \
      "$KUBE_ROOT/cluster/linode/templates/common.sh" > \
      "$KUBE_TEMP/stackscript-master.sh"

  MASTER_STACKSCRIPT=$(ensure-stackscript "$KUBE_TEMP/stackscript-master.sh" "kubernetes-master")
}


## Getting things

function get-kubeconfig {
  export KUBE_CERT="/tmp/$RANDOM-kubecfg.crt"
  export KUBE_KEY="/tmp/$RANDOM-kubecfg.key"
  export CA_CERT="/tmp/$RANDOM-kubernetes.ca.crt"
  export CONTEXT="linode_${INSTANCE_PREFIX}"

  local kubectl="${KUBE_ROOT}/cluster/kubectl.sh"

  # TODO: generate ADMIN (and KUBELET) tokens and put those in the master's
  # config file.  Distribute the same way the htpasswd is done.
  (
    umask 077
    do-ssh "${KUBE_MASTER_IP}" sudo cat /srv/kubernetes/kubecfg.crt >"${KUBE_CERT}" 2>"$LOG"
    do-ssh "${KUBE_MASTER_IP}" sudo cat /srv/kubernetes/kubecfg.key >"${KUBE_KEY}" 2>"$LOG"
    do-ssh "${KUBE_MASTER_IP}" sudo cat /srv/kubernetes/ca.crt >"${CA_CERT}" 2>"$LOG"

    create-kubeconfig
  )
}

function do-ssh {
  ssh -oStrictHostKeyChecking=no -i "${SSH_KEY}" "root@$1" "${@:2}"
}

function get_linode_ip {
  get_linode_info_json $1 | jq "$jq_select_public_ip" | xargs
}
function get_linode_private_ip {
  get_linode_info_json $1 | jq "$jq_select_private_ip" | xargs
}

function get_minion_ips {
  get_minion_list_json | jq "$jq_select_public_ip" | xargs
}

function get_minion_labels {
  get_minion_list_json | jq ".label" | xargs
}

## Resolving information

function resolve-distro {
  case "${KUBE_OS_DISTRIBUTION}" in
    vivid|ubuntu)
      LINODE_DISTRIBUTION="Ubuntu 15.04"
      ;;
    jessie|debian)
      LINODE_DISTRIBUTION="Debian 8.1"
      ;;
    *)
      echo "Cannot start cluster using os distro: ${KUBE_OS_DISTRIBUTION}" >&2
      exit 2
      ;;
  esac
}

function resolve-api-key {
  LINODE_API_KEY=$(cat ~/.linodecli/config | grep api-key | cut -d' ' -f2)
}


# Ensure that we have a password created for validating to the master.  Will
# read from kubeconfig for the current context if available.
#
# Vars set:
#   KUBE_USER
#   KUBE_PASSWORD
function resolve-admin-user {
  get-kubeconfig-basicauth
  if [[ -z "${KUBE_USER}" || -z "${KUBE_PASSWORD}" ]]; then
    KUBE_USER=admin
    KUBE_PASSWORD=$(python -c 'import string,random; print "".join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(16))')
  fi
}

## Misc

function wait-for-master {
  wait-for-ssh-cmd $KUBE_MASTER_IP "uptime" "master to be up"
  wait-for-ssh-cmd $KUBE_MASTER_IP "pgrep salt-master" "salt-master to be started on master"
}

function wait-for-minions {
  for minion in $KUBE_MINION_IP_ADDRESSES; do
    wait-for-ssh-cmd $minion "uptime" "minion $minion to be up"
    wait-for-ssh-cmd $minion "pgrep salt-minion" "salt-minion to be started on minion $minion"
  done
}

function wait-for-master {
  echo "Waiting for cluster initialization."
  echo
  echo "  This will continually check to see if the API for kubernetes is reachable."
  echo "  This might loop forever if there was some uncaught error during start"
  echo "  up."
  echo

  until $(curl --insecure --user ${KUBE_USER}:${KUBE_PASSWORD} --max-time 5 \
               --fail --output $LOG --silent https://${KUBE_MASTER_IP}/healthz); do
    printf "."
    sleep 2
  done
}

########## 2nd level utilities ##############

jq_select_private_ip='.ips[] | select(startswith("192.168"))'
jq_select_public_ip='.ips[] | select(startswith("192.168") == false)'

function get_minion_list_json {
  get_linode_list_json \
| jq ".[] | select(.group == $LINODE_GROUP)"
}

function get_linode_info_json {
  get_linode_list_json | jq ".$1"
}

LINODE_LIST=
function get_linode_list_json {
  if [[ -z $LINODE_LIST ]]; then
    LINODE_LIST=$(linode list --output json)
  fi
  echo $LINODE_LIST
}

# Arguments
# - label / hostname
# - plan size
# - ismaster ("true" or "false")
function create-linode {
  linode create --location "${LINODE_DATACENTER}" \
                --distribution "${LINODE_DISTRIBUTION}" \
                --password "${ROOT_PASSWORD}" \
                --group "${LINODE_GROUP}" \
                --pubkey-file "${SSH_KEY}.pub" \
                $1
}

function delete-linode {
  linode delete --label $1
}

## Make sure a stackscript is created on your account
## We label the stackscript as follows:
##  Hash the contents of the file and prepend it by a prefix
## Inputs: $1 filename
##         $2 prefix
## Returns via echo: label
function ensure-stackscript {
  local file=$1
  local prefix=$2
  local hash=$(shasum $file | cut -d' ' -f1)
  local label="$prefix-$hash"

  local exists=$(linode stackscript show --label $label 2>/dev/null)
  if [[ -z $exists ]]; then
    linode stackscript create --label $label \
                              --distribution $LINODE_DISTRIBUTION \
                              --codefile $file \
                              >/dev/null
  fi
  echo $label # return statement
}

function wait-for-ssh-cmd {
  IP=$1
  CMD=$2
  REASON=$3
  # Check for SSH connectivity
  attempt=0
  while true; do
    echo -n Attempt "$(($attempt+1))" to check for $REASON
    local output
    local ok=1
    output=$(do-ssh $IP $CMD 2> $LOG) || ok=0
    if [[ ${ok} == 0 ]]; then
      if (( attempt > 30 )); then
        echo
        echo "(Failed) output was: ${output}"
        echo
        echo -e "${color_red}Failed! $REASON (IP: $IP). Your cluster is unlikely" >&2
        echo "to work correctly. Please run ./cluster/kube-down.sh and re-create the" >&2
        echo -e "cluster. (sorry!)${color_norm}" >&2
        exit 1
      fi
    else
      echo -e " ${color_green}[$REASON working]${color_norm}"
      break
    fi
    echo -e " ${color_yellow}[$REASON not working yet]${color_norm}"
    attempt=$(($attempt+1))
    sleep 10
  done
}


##@yanatan16: My syntax highlighter hates this function, so its down here
function create-tokens() {
  KUBELET_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
  KUBE_PROXY_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
}