locals {
  lb_private_ips = [for k, v in var.private_subnet_cidrs : cidrhost(v, 16)]
}

module "es_load_balancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = var.load_balancer_name
  load_balancer_type = "network"
  vpc_id             = var.vpc_id

  subnet_mapping = [for idx, i in local.lb_private_ips : { private_ipv4_address : i, subnet_id : var.private_subnets[idx] }]
  internal       = true

  http_tcp_listeners = [
    {
      port               = 9200
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 5601
      protocol           = "TCP"
      target_group_index = 1
    }
  ]

  target_groups = [
    {
      name_prefix      = "es-"
      backend_protocol = "TCP"
      backend_port     = 9200
      target_type      = "instance"
    },
    {
      name_prefix      = "kib-"
      backend_protocol = "TCP"
      backend_port     = 5601
      target_type      = "instance"
    }
  ]
}