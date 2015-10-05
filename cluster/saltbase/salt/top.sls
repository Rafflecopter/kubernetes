base:
  '*':
    - base
    - debian-auto-upgrades
    - salt-helpers

  'roles:kubernetes-pool':
    - match: grain
    - docker
{% if grains['cloud'] is defined and grains['cloud'] == 'azure' %}
    - openvpn-client
{% endif %}
    - helpers
    - cadvisor
    - kube-client-tools
    - kubelet
    - kube-proxy
{% if pillar.get('enable_node_logging', '').lower() == 'true' and pillar['logging_destination'] is defined %}
  {% if pillar['logging_destination'] == 'elasticsearch' %}
    - fluentd-es
  {% elif pillar['logging_destination'] == 'gcp' %}
    - fluentd-gcp
  {% endif %}
{% endif %}
    - logrotate
{% if grains['cloud'] is defined and grains.cloud == 'gce' %}
    - supervisor
{% else %}
    - monit
{% endif %}
{% if grains.network_mode is defined and grains.network_mode == 'flannel' %}
    - flannel
{% endif %}

  'roles:kubernetes-master':
    - match: grain
    - generate-cert
    - etcd
    - kube-apiserver
    - kube-controller-manager
    - kube-scheduler
{% if grains['cloud'] is defined and grains.cloud == 'gce' %}
    - supervisor
{% else %}
    - monit
{% endif %}
{% if grains['cloud'] is defined and not grains.cloud in [ 'aws', 'gce', 'vagrant', 'linode' ] %}
    - nginx
{% endif %}
    - cadvisor
    - kube-client-tools
    - kube-master-addons
    - kube-admission-controls
{% if pillar.get('enable_node_logging', '').lower() == 'true' and pillar['logging_destination'] is defined %}
  {% if pillar['logging_destination'] == 'elasticsearch' %}
    - fluentd-es
  {% elif pillar['logging_destination'] == 'gcp' %}
    - fluentd-gcp
  {% endif %}
{% endif %}
{% if grains['cloud'] is defined and grains['cloud'] != 'vagrant' %}
    - logrotate
{% endif %}
    - kube-addons
{% if grains['cloud'] is defined and grains['cloud'] == 'azure' %}
    - openvpn
{% endif %}
{% if grains['cloud'] is defined and grains['cloud'] in [ 'vagrant', 'gce', 'aws', 'linode' ] %}
    - docker
    - kubelet
{% endif %}
{% if grains['network_mode'] is defined and grains['network_mode'] == 'flannel' %}
    - flannel
{% endif %}

  'roles:kubernetes-pool-vsphere':
    - match: grain
    - static-routes

  'roles:glusterfs':
    - match: grain
    - glusterfs

  'cloud:linode':
    - match: grain
    - hosts