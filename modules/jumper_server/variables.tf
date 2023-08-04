variable "vpc_id" {
  type = string
}

variable "jumper_security_group_name" {
  type    = string
  default = "jumper_security_group"
}

variable "jumper_instance_type" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "ami" {
  type = string
}

variable "key_name" {
  type = string
}

variable "es_key_name" {
  type = string
}

variable "kibana_key_name" {
  type = string
}

variable "account_id" {
  type = string
}