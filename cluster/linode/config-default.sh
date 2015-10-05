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

LINODE_DATACENTER=${LINODE_DATACENTER:-newark}
MASTER_SIZE=${MASTER_SIZE:-1024}
MINION_SIZE=${MINION_SIZE:-1024}
NUM_MINIONS=${NUM_MINIONS:-4}

## FUTURE
NUM_GLUSTERFS=${NUM_GLUSTERFS:-0}
GLUSTERFS_SIZE=${GLUSTERFS_SIZE:-8192}
GLUSTERFS_LABEL=${GLUSTERFS_LABEL:-glusterfs}

# Which docker storage mechanism to use. aufs only for now
DOCKER_STORAGE=aufs

SSH_KEY=${SSH_KEY:-$HOME/.ssh/kube_linode_rsa}

LINODE_DOMAIN=${LINODE_DOMAIN:-}
INSTANCE_PREFIX="${INSTANCE_PREFIX:-kubernetes}"
LINODE_GROUP="${INSTANCE_PREFIX}-group"
CLUSTER_ID=${INSTANCE_PREFIX}
LOG="/dev/null"
ROOT_PASSWORD="${ROOT_PASSWORD:-kubetest}"
SALT_VERSION=${SALT_VERSION:-v2015.5.5}

KUBE_USER=${KUBE_USER:-}
KUBE_PASSWORD=${KUBE_PASSWORD:-}

LINODE_UPLOAD_STACKSCRIPT=true

MASTER_LABEL="${INSTANCE_PREFIX}-master"
MINION_LABEL="${INSTANCE_PREFIX}-minion"
POLL_SLEEP_INTERVAL=3
SERVICE_CLUSTER_IP_RANGE="10.0.0.0/16"  # formerly PORTAL_NET
CLUSTER_IP_RANGE="${CLUSTER_IP_RANGE:-10.244.0.0/16}"
MASTER_IP_RANGE="${MASTER_IP_RANGE:-10.246.0.0/24}"

# Optional: Cluster monitoring to setup as part of the cluster bring up:
#   none     - No cluster monitoring setup
#   influxdb - Heapster, InfluxDB, and Grafana
ENABLE_CLUSTER_MONITORING="${KUBE_ENABLE_CLUSTER_MONITORING:-influxdb}"

# Optional: Enable node logging.
ENABLE_NODE_LOGGING="${KUBE_ENABLE_NODE_LOGGING:-true}"
LOGGING_DESTINATION="${KUBE_LOGGING_DESTINATION:-elasticsearch}" # options: elasticsearch, gcp

# Optional: When set to true, Elasticsearch and Kibana will be setup as part of the cluster bring up.
ENABLE_CLUSTER_LOGGING="${KUBE_ENABLE_CLUSTER_LOGGING:-true}"
ELASTICSEARCH_LOGGING_REPLICAS=1

# Optional: Don't require https for registries in our local RFC1918 network
if [[ ${KUBE_ENABLE_INSECURE_REGISTRY:-false} == "true" ]]; then
  EXTRA_DOCKER_OPTS="--insecure-registry 10.0.0.0/8"
fi

# Optional: Install cluster DNS.
ENABLE_CLUSTER_DNS=true
DNS_SERVER_IP="10.0.0.10"
DNS_DOMAIN="cluster.local"
DNS_REPLICAS=1

# Admission Controllers to invoke prior to persisting objects in cluster
ADMISSION_CONTROL=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota

# Optional: Enable/disable public IP assignment for minions.
# Important Note: disable only if you have setup a NAT instance for internet access and configured appropriate routes!
ENABLE_MINION_PUBLIC_IP=${KUBE_ENABLE_MINION_PUBLIC_IP:-true}

# OS options for minions
KUBE_OS_DISTRIBUTION="${KUBE_OS_DISTRIBUTION:-vivid}"
KUBE_MINION_IMAGE="${KUBE_MINION_IMAGE:-}"
COREOS_CHANNEL="${COREOS_CHANNEL:-alpha}"
CONTAINER_RUNTIME="${KUBE_CONTAINER_RUNTIME:-docker}"
RKT_VERSION="${KUBE_RKT_VERSION:-0.5.5}"

