#!/bin/bash
# This block defines the variables the user of the script needs to input
# when deploying using this script.
#
#<UDF name="domain" label="The new Linode's Domain Name">
#<UDF name="saltversion" label="The saltstack version." default="v2015.5.5">
#<UDF name="apikey" label="The Linode api key of the salt-master.">
#
#<UDF name="server_binary_tar_url" label="Env var: SERVER_BINARY_TAR_URL">
#<UDF name="salt_tar_url" label="Env var: SALT_TAR_URL">
#<UDF name="instance_prefix" label="Env var: INSTANCE_PREFIX"
#<UDF name="node_instance_prefix" label="Env var: NODE_INSTANCE_PREFIX"
#<UDF name="service_cluster_ip_range" label="Env var: SERVICE_CLUSTER_IP_RANGE"
#<UDF name="enable_cluster_monitoring" label="Env var: ENABLE_CLUSTER_MONITORING"
#<UDF name="enable_cluster_logging" label="Env var: ENABLE_CLUSTER_LOGGING"
#<UDF name="enable_node_logging" label="Env var: ENABLE_NODE_LOGGING"
#<UDF name="logging_destination" label="Env var: LOGGING_DESTINATION"
#<UDF name="elasticsearch_logging_replicas" label="Env var: ELASTICSEARCH_LOGGING_REPLICAS"
#<UDF name="enable_cluster_dns" label="Env var: ENABLE_CLUSTER_DNS"
#<UDF name="dns_replicas" label="Env var: DNS_REPLICAS"
#<UDF name="dns_server_ip" label="Env var: DNS_SERVER_IP"
#<UDF name="dns_domain" label="Env var: DNS_DOMAIN"
#<UDF name="admission_control" label="Env var: ADMISSION_CONTROL"
#<UDF name="kube_user" label="Env var: KUBE_USER"
#<UDF name="kube_password" label="Env var: KUBE_PASSWORD"
#<UDF name="kubelet_token" label="Env var: KUBELET_TOKEN"
#<UDF name="kube_proxy_token" label="Env var: KUBE_PROXY_TOKEN"

function main {
  validate-inputs
  basic-setup
  install-saltstack master
  install-salt-overlay
  install-saltbase
  configure-salt
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

function configure-salt {
  cat <<EOF >/etc/salt/minion
master: $LABEL
id: $LABEL
EOF

  mkdir -p /etc/salt/minion.d
  cat <<EOF >/etc/salt/minion.d/grains.conf
grains:
  roles:
    - kubernetes-master
  cloud: linode
  network_mode: flannel
  etcd_servers: http://$LABEL:4001
  api_servers: $LABEL
EOF

  mkdir -p /etc/salt/master.d
  cat <<EOF >/etc/salt/master.d/auto-accept.conf
auto_accept: True
EOF

  cat <<EOF >/etc/salt/master.d/reactor.conf
# React to new minions starting by running highstate on everything (due to host routing).
reactor:
  - 'salt/minion/*/start':
    - /srv/reactor/highstate-minions.sls
    - /srv/reactor/highstate-masters.sls
EOF

  salt-key --gen-keys=minion --gen-keys-dir=/etc/salt/pki/minion
  service salt-master restart
  service salt-minion restart
  echo 'Salt master and minion configured'
}

function install-saltbase {
  mkdir -p /tmp/kubernetes >$LOG 2>&1
  rm -rf /tmp/kubernetes/* >$LOG 2>&1
  wget $SALT_TAR_URL -O /tmp/kubernetes-salt.tar.gz >$LOG 2>&1
  tar xzvf /tmp/kubernetes-salt.tar.gz -C /tmp >$LOG 2>&1
  /tmp/kubernetes/saltbase/install.sh "${SERVER_BINARY_TAR_URL##*/}" >$LOG 2>&1

  echo "Installed salt files!" | tee $LOG
}

function install-salt-overlay {
  mkdir -p /srv/salt-overlay/pillar
  cat <<EOF >/srv/salt-overlay/pillar/cluster-params.sls
instance_prefix: '$(echo "$INSTANCE_PREFIX" | sed -e "s/'/''/g")'
node_instance_prefix: '$(echo "$NODE_INSTANCE_PREFIX" | sed -e "s/'/''/g")'
service_cluster_ip_range: '$(echo "$SERVICE_CLUSTER_IP_RANGE" | sed -e "s/'/''/g")'
enable_cluster_monitoring: '$(echo "$ENABLE_CLUSTER_MONITORING" | sed -e "s/'/''/g")'
enable_cluster_logging: '$(echo "$ENABLE_CLUSTER_LOGGING" | sed -e "s/'/''/g")'
enable_node_logging: '$(echo "$ENABLE_NODE_LOGGING" | sed -e "s/'/''/g")'
logging_destination: '$(echo "$LOGGING_DESTINATION" | sed -e "s/'/''/g")'
elasticsearch_replicas: '$(echo "$ELASTICSEARCH_LOGGING_REPLICAS" | sed -e "s/'/''/g")'
enable_cluster_dns: '$(echo "$ENABLE_CLUSTER_DNS" | sed -e "s/'/''/g")'
dns_replicas: '$(echo "$DNS_REPLICAS" | sed -e "s/'/''/g")'
dns_server: '$(echo "$DNS_SERVER_IP" | sed -e "s/'/''/g")'
dns_domain: '$(echo "$DNS_DOMAIN" | sed -e "s/'/''/g")'
admission_control: '$(echo "$ADMISSION_CONTROL" | sed -e "s/'/''/g")'
EOF

  readonly BASIC_AUTH_FILE="/srv/salt-overlay/salt/kube-apiserver/basic_auth.csv"
  if [ ! -e "${BASIC_AUTH_FILE}" ]; then
    mkdir -p /srv/salt-overlay/salt/kube-apiserver
    (umask 077;
      echo "${KUBE_PASSWORD},${KUBE_USER},admin" > "${BASIC_AUTH_FILE}")
  fi

  # Generate and distribute a shared secret (bearer token) to
  # apiserver and the nodes so that kubelet and kube-proxy can
  # authenticate to apiserver.
  kubelet_token=$KUBELET_TOKEN
  kube_proxy_token=$KUBE_PROXY_TOKEN

  # Make a list of tokens and usernames to be pushed to the apiserver
  mkdir -p /srv/salt-overlay/salt/kube-apiserver
  readonly KNOWN_TOKENS_FILE="/srv/salt-overlay/salt/kube-apiserver/known_tokens.csv"
  (umask u=rw,go= ; echo "$kubelet_token,kubelet,kubelet" > $KNOWN_TOKENS_FILE ;
  echo "$kube_proxy_token,kube_proxy,kube_proxy" >> $KNOWN_TOKENS_FILE)

  mkdir -p /srv/salt-overlay/salt/kubelet
  kubelet_auth_file="/srv/salt-overlay/salt/kubelet/kubernetes_auth"
  (umask u=rw,go= ; echo "{\"BearerToken\": \"$kubelet_token\", \"Insecure\": true }" > $kubelet_auth_file)

  mkdir -p /srv/salt-overlay/salt/kube-proxy
  kube_proxy_kubeconfig_file="/srv/salt-overlay/salt/kube-proxy/kubeconfig"
  cat > "${kube_proxy_kubeconfig_file}" <<EOF
apiVersion: v1
kind: Config
users:
- name: kube-proxy
  user:
    token: ${kube_proxy_token}
clusters:
- name: local
  cluster:
     insecure-skip-tls-verify: true
contexts:
- context:
    cluster: local
    user: kube-proxy
  name: service-account-context
current-context: service-account-context
EOF

  mkdir -p /srv/salt-overlay/salt/kubelet
  kubelet_kubeconfig_file="/srv/salt-overlay/salt/kubelet/kubeconfig"
  cat > "${kubelet_kubeconfig_file}" <<EOF
apiVersion: v1
kind: Config
users:
- name: kubelet
  user:
    token: ${kubelet_token}
clusters:
- name: local
  cluster:
     insecure-skip-tls-verify: true
contexts:
- context:
    cluster: local
    user: kubelet
  name: service-account-context
current-context: service-account-context
EOF

  # Generate tokens for other "service accounts".  Append to known_tokens.
  #
  # NB: If this list ever changes, this script actually has to
  # change to detect the existence of this file, kill any deleted
  # old tokens and add any new tokens (to handle the upgrade case).
  service_accounts=("system:scheduler" "system:controller_manager" "system:logging" "system:monitoring" "system:dns")
  for account in "${service_accounts[@]}"; do
    token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
    echo "${token},${account},${account}" >> "${KNOWN_TOKENS_FILE}"
  done

  echo "Created salt overlay files!" | tee $LOG
}