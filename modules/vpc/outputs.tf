output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "private_subnet_cidrs" {
  description = "List of calculated cidr ranges for private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}


output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "azs" {
  description = "List of VPC azs"
  value       = module.vpc.azs
}