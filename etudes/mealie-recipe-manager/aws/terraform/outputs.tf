output "frontend_url" {
  value = "http://${module.mealie_frontend.frontend_alb.lb_dns_name}/"
}

