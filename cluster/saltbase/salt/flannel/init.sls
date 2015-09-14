{% if pillar.get('is_systemd') %}
{% set environment_file = '/etc/sysconfig/flanneld' %}
{% else %}
{% set environment_file = '/etc/default/flanneld' %}
{% endif %}

/usr/local/bin/flanneld:
  file.managed:
    - source: salt://kube-bins/flanneld
    - makedirs: true
    - user: root
    - group: root
    - mode: 755

{{ environment_file }}:
  file.managed:
    - source: salt://flannel/default
    - template: jinja
    - user: root
    - group: root
    - mode: 644

flannel:
  group.present:
    - system: True
  user.present:
    - system: True
    - gid_from_name: True
    - shell: /sbin/nologin
    - home: /var/flannel
    - require:
      - group: flannel

{% if pillar.get('is_systemd') %}

{{ pillar.get('systemd_system_path') }}/flanneld.service:
  file.managed:
    - source: salt://flannel/flanneld.service
    - user: root
    - group: root
  cmd.wait:
    - name: /opt/kubernetes/helpers/services bounce flanneld
    - watch:
      - file: {{ environment_file }}
      - file: {{ pillar.get('systemd_system_path') }}/flanneld.service

{% else %}

/etc/init.d/flanneld:
  file.managed:
    - source: salt://flannel/initd
    - user: root
    - group: root
    - mode: 755

{% endif %}

flanneld-service:
  service.running:
    - name: flanneld
    - enable: True
    - watch:
      - file: {{ environment_file }}
      - file: /usr/local/bin/flanneld
{% if pillar.get('is_systemd') %}
      - file: {{ pillar.get('systemd_system_path') }}/flanneld.service
{% else %}
      - file: /etc/init.d/flanneld
{% endif %}
