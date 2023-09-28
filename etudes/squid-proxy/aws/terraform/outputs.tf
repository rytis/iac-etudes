output "instance_id" {
  value = module.server.id
}

output "external_ip" {
  value = module.server.public_ip
}
