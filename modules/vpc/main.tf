module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  enable_nat_gateway = true
  enable_vpn_gateway = false

  azs = var.azs

  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
}