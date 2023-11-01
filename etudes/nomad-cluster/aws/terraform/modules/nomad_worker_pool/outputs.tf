output "instance_ids" {
  value = module.nomad_worker[*].id
}
