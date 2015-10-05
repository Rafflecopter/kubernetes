{% for host, ips in salt['mine.get']('*', 'network.ip_addrs').items() %}
{% for ip in ips %}
{% if '192.168' in ip %}

{{host}}:
  host.present:
    - ip: {{ip}}
    - names:
      - {{host}}
      {% if host.split('.')[0] != host %}
      - {{host.split('.')[0]}}
      {% endif %}

{% endif %}
{% endfor %}
{% endfor %}