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

# This script will set up the salt directory on the target server.  It takes one
# argument that is a tarball with the pre-compiled kubernetes server binaries.

set -o errexit
set -o nounset
set -o pipefail

SALT_ROOT=$(dirname "${BASH_SOURCE}")
readonly SALT_ROOT

KUBE_VERSION="$1"
readonly KUBE_VERSION

if [[ -z "$KUBE_VERSION" ]]; then
  echo "!!! No version specified"
  exit 1
fi

readonly SERVER_BIN_TAR=${2-}
if [[ -z "$SERVER_BIN_TAR" ]]; then
  echo "!!! No binaries specified"
  exit 1
fi

# Create a temp dir for untaring
KUBE_TEMP=$(mktemp -d -t kubernetes.XXXXXX)
trap 'rm -rf "${KUBE_TEMP}"' EXIT

# This file is meant to run on the master.  It will install the salt configs
# into the appropriate place on the master.  We do this by creating a new set of
# salt trees and then quickly mv'ing them where the old ones were.

readonly SALTDIRS=(salt pillar reactor)

echo "+++ Installing salt files into new trees"
rm -rf /srv/salt-new
mkdir -p /srv/salt-new

# This bash voodoo will prepend $SALT_ROOT to the start of each item in the
# $SALTDIRS array
cp -v -R --preserve=mode "${SALTDIRS[@]/#/${SALT_ROOT}/}" /srv/salt-new

echo "+++ Installing salt overlay files"
for dir in "${SALTDIRS[@]}"; do
  if [[ -d "/srv/salt-overlay/$dir" ]]; then
    cp -v -R --preserve=mode "/srv/salt-overlay/$dir" "/srv/salt-new/"
  fi
done

echo "+++ Install binaries from tar: $SERVER_BIN_TAR"
tar -xz -C "${KUBE_TEMP}" -f "$SERVER_BIN_TAR"
mkdir -p /srv/salt-new/salt/kube-bins
cp -v "${KUBE_TEMP}/kubernetes/server/bin/"* /srv/salt-new/salt/kube-bins/

docker_images_sls_file="/srv/salt-new/pillar/docker-images.sls";
sed -i "s/#hyperkube_docker_tag_value#/${KUBE_VERSION}/" "${docker_images_sls_file}";

echo "+++ Swapping in new configs"
for dir in "${SALTDIRS[@]}"; do
  if [[ -d "/srv/$dir" ]]; then
    rm -rf "/srv/$dir"
  fi
  mv -v "/srv/salt-new/$dir" "/srv/$dir"
done

rm -rf /srv/salt-new
