output "private_ips" {
  description = "List of calculated ips for LB network interfaces"
  value       = local.lb_private_ips
}

output "target_group_arns" {
  description = "ARNs of lb target group"
  value       = module.es_load_balancer.target_group_arns
}

output "lb_dns_name" {
  description = "DNS name of the nlb"
  value       = module.es_load_balancer.lb_dns_name
}

