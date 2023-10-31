data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

log_level = "DEBUG"

server {
  enabled          = true
  bootstrap_expect = {{ _nomad_server_cluster_size }}
  server_join = {
    retry_join = [
      "{{ _nomad_server_autojoin_string }}"
    ]
  }
}

client {
  enabled = true
  servers = ["127.0.0.1"]
}
