output "public_ips" {
  value = module.nomad_server[*].public_ip
}

output "instance_ids" {
  value = module.nomad_server[*].id
}
