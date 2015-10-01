glusterfs-server:
  pkg.installed: []

/data/brick1:
  file.directory:
    makedirs: true

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

glusterd:
  service.started:
    - requires:
      - pkg: glusterfs-server
      - mount: /data/brick1