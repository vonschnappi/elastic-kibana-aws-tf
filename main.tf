data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu22" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_availability_zones" "available" {}


locals {
  private_subnet_cidrs = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnet_cidrs  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source               = "./modules/vpc"
  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs
}

module "es_load_balancer" {
  source               = "./modules/es_load_balancer"
  vpc_id               = module.vpc.vpc_id
  load_balancer_name   = var.load_balancer_name
  private_subnets      = module.vpc.private_subnets
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
}

module "jumper_server" {
  source                     = "./modules/jumper_server"
  key_name                   = var.jumper_key_name
  es_key_name                = var.es_key_name
  kibana_key_name            = var.kibana_key_name
  public_subnets             = module.vpc.public_subnets
  vpc_id                     = module.vpc.vpc_id
  jumper_security_group_name = var.jumper_security_group_name
  ami                        = data.aws_ami.ubuntu22.id
  jumper_instance_type       = var.jumper_instance_type
  account_id                 = data.aws_caller_identity.current.account_id
}

module "elastic_cluster" {
  source                     = "./modules/elastic_cluster"
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr                   = var.vpc_cidr
  lb_target_group_arns       = module.es_load_balancer.target_group_arns
  lb_dns_name                = module.es_load_balancer.lb_dns_name
  es_key_name                = var.es_key_name
  kibana_key_name            = var.kibana_key_name
  es_security_group_name     = var.es_security_group_name
  kibana_security_group_name = var.kibana_security_group_name
  jumper_security_group_id   = module.jumper_server.security_group_id
  es_master_instance_type    = var.es_master_instance_type
  es_data_instance_type      = var.es_data_instance_type
  kibana_instance_type       = var.kibana_instance_type
  ami                        = data.aws_ami.ubuntu22.id
  private_subnets            = module.vpc.private_subnets
  azs                        = module.vpc.azs
  account_id                 = data.aws_caller_identity.current.account_id
}

