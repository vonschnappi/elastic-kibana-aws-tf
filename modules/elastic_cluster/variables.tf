variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "lb_target_group_arns" {
  type = list(string)
}

variable "lb_dns_name" {
  type = string
}

variable "es_security_group_name" {
  type = string
}

variable "kibana_security_group_name" {
  type = string
}

variable "jumper_security_group_id" {
  type = string
}

variable "es_master_instance_type" {
  type = string
}

variable "es_data_instance_type" {
  type = string
}

variable "kibana_instance_type" {
  type = string
}

variable "es_key_name" {
  type = string
}

variable "kibana_key_name" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "ami" {
  type = string
}

variable "account_id" {
  type = string
}