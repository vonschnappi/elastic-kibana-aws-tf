variable "vpc_id" {
  type = string
}

variable "load_balancer_name" {
  type    = string
  default = "elastic-nlb"
}

variable "private_subnets" {
  type = list(any)
}

variable "private_subnet_cidrs" {
  type = list(any)
}