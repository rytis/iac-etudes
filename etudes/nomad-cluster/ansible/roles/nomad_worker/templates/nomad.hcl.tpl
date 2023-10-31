data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

log_level = "DEBUG"

server {
  enabled          = false
}

client {
  enabled = true
  server_join = {
    retry_join = [
      "{{ _nomad_server_autojoin_string }}"
    ]
  }
}
