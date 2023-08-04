variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  type    = string
  default = "MyVPC"
}

variable "jumper_key_name" {
  type    = string
  default = "jumper"
}

variable "es_key_name" {
  type    = string
  default = "es"
}

variable "kibana_key_name" {
  type    = string
  default = "kibana"
}

variable "load_balancer_name" {
  type    = string
  default = "elastic-nlb"
}

variable "es_security_group_name" {
  type    = string
  default = "es_security_group"
}

variable "kibana_security_group_name" {
  type    = string
  default = "kibana_security_group"
}

variable "jumper_security_group_name" {
  type    = string
  default = "jumper_security_group"
}

variable "jumper_instance_type" {
  type    = string
  default = "t2.medium"
}

variable "es_master_instance_type" {
  type    = string
  default = "t2.large"
}

variable "es_data_instance_type" {
  type    = string
  default = "t2.large"
}

variable "kibana_instance_type" {
  type    = string
  default = "t2.large"
}




