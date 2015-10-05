glusterfs-server:
  pkg.installed: []
  service.running:
    - enable: true
    - requires:
      - pkg: glusterfs-server
      - mount: /data/brick1

/data/brick1:
  mount.mounted:
    - device: {{grains['glusterfs_device_name']}}
    - fstype: {{grains['glusterfs_device_fstype']}}
    - user: root
    - mount: true
    - persist: True
    - mkmnt: true
    - dump: 1
    - pass_num: 2