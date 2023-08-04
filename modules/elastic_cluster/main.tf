data "template_file" "es_data_user_data" {
  template = file("${path.cwd}/modules/elastic_cluster/files/es_user_data.tpl")
  vars = {
    role      = "data"
    data_path = "/data"
    node_name = "$${node_name}"
  }
}

data "template_file" "es_master_user_data" {
  template = file("${path.cwd}/modules/elastic_cluster/files/es_user_data.tpl")
  vars = {
    role      = "master"
    data_path = "/var/lib/elasticsearch"
    node_name = "$${node_name}"
  }
}

data "template_file" "kibana_user_data" {
  template = file("${path.cwd}/modules/elastic_cluster/files/kibana_user_data.tpl")
  vars = {
    lb_dns_name = var.lb_dns_name
  }
}

locals {
  es_target_group_arn     = var.lb_target_group_arns[0]
  kibana_target_group_arn = var.lb_target_group_arns[1]
  es_role_arn             = "arn:aws:iam::${var.account_id}:role/es_node"
}

module "es_key_pair" {
  source             = "terraform-aws-modules/key-pair/aws"
  key_name           = var.es_key_name
  create_private_key = true
}

resource "aws_secretsmanager_secret" "es_key" {
  name = "ssh/es_key"
}

resource "aws_secretsmanager_secret_version" "es_key" {
  secret_id     = aws_secretsmanager_secret.es_key.id
  secret_string = module.es_key_pair.private_key_pem
}

module "kibana_key_pair" {
  source             = "terraform-aws-modules/key-pair/aws"
  key_name           = var.kibana_key_name
  create_private_key = true
}

resource "aws_secretsmanager_secret" "kibana_key" {
  name = "ssh/kibana_key"
}

resource "aws_secretsmanager_secret_version" "kibana_key" {
  secret_id     = aws_secretsmanager_secret.kibana_key.id
  secret_string = module.kibana_key_pair.private_key_pem
}

module "es_security_group" {

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.es_security_group_name
  description = "Security group for elastic nodes"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 9200
      to_port     = 9200
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr
    }
  ]

  ingress_with_source_security_group_id = [
    {
      from_port                = 9200
      to_port                  = 9300
      protocol                 = "tcp"
      source_security_group_id = module.es_security_group.security_group_id
    },
    {
      from_port                = 9200
      to_port                  = 9200
      protocol                 = "tcp"
      source_security_group_id = module.kibana_security_group.security_group_id
    },
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_id = var.jumper_security_group_id
    }
  ]
  egress_rules = ["all-all"]

}

module "kibana_security_group" {

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.kibana_security_group_name
  description = "Security group for kibana"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5601
      to_port     = 5601
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr
    }
  ]

  ingress_with_source_security_group_id = [
    {
      from_port                = 5601
      to_port                  = 5601
      protocol                 = "tcp"
      source_security_group_id = module.kibana_security_group.security_group_id
    },
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_id = var.jumper_security_group_id
    }
  ]
  egress_rules = ["all-all"]
}

resource "aws_iam_policy" "es_node" {
  name = "es_node"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets"
        ],
        "Resource" : "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances"
        ],
        "Resource" : "*"
      }
    ]
  })
}


resource "aws_iam_role" "es_node" {
  name = "es-node"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com",
               "AWS": "arn:aws:iam::${var.account_id}:role/es-node"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "es_node_policy_attachment" {
  role       = aws_iam_role.es_node.name
  policy_arn = aws_iam_policy.es_node.arn
}

resource "aws_iam_instance_profile" "es_node" {
  name = "es_node"
  role = aws_iam_role.es_node.name
}

module "es_data_nodes" {
  source = "terraform-aws-modules/ec2-instance/aws"
  ami    = var.ami

  for_each = { 0 : "es-data-1", 1 : "es-data-2", 2 : "es-data-3" }
  name     = each.value

  instance_type          = var.es_data_instance_type
  key_name               = var.es_key_name
  monitoring             = true
  vpc_security_group_ids = [module.es_security_group.security_group_id]
  subnet_id              = var.private_subnets[each.key]

  iam_instance_profile = aws_iam_instance_profile.es_node.name

  root_block_device = [{
    encrypted = true
  }]
  enable_volume_tags = true
  metadata_options = {
    "http_endpoint" : "enabled",
    "http_put_response_hop_limit" : 1,
    "http_tokens" : "optional",
    "instance_metadata_tags" : "enabled"
  }

  tags = {
    Terraform    = "true"
    Role         = "es-data"
    cluster_name = "es-cluster"
  }

  user_data = data.template_file.es_data_user_data.rendered
}

module "es_master_nodes" {
  source = "terraform-aws-modules/ec2-instance/aws"
  ami    = var.ami

  for_each = { 0 : "es-master-1", 1 : "es-master-2", 2 : "es-master-3" }
  name     = each.value

  instance_type          = var.es_master_instance_type
  key_name               = var.es_key_name
  monitoring             = true
  vpc_security_group_ids = [module.es_security_group.security_group_id]
  subnet_id              = var.private_subnets[each.key]

  iam_instance_profile = aws_iam_instance_profile.es_node.name

  root_block_device = [{
    encrypted = true
  }]
  enable_volume_tags = true
  metadata_options = {
    "http_endpoint" : "enabled",
    "http_put_response_hop_limit" : 1,
    "http_tokens" : "optional",
    "instance_metadata_tags" : "enabled"
  }

  tags = {
    Terraform    = "true"
    Role         = "es-master"
    cluster_name = "es-cluster"
  }

  user_data = data.template_file.es_master_user_data.rendered
}

module "es_kibana_node" {
  source = "terraform-aws-modules/ec2-instance/aws"
  ami    = var.ami

  name                   = "kibana"
  instance_type          = var.es_data_instance_type
  key_name               = var.kibana_key_name
  monitoring             = true
  vpc_security_group_ids = [module.kibana_security_group.security_group_id]
  subnet_id              = var.private_subnets[0]
  root_block_device = [{
    encrypted = true
    }

  ]
  enable_volume_tags = true

  tags = {
    Terraform = "true"
    Role      = "kibana"
  }

  user_data = data.template_file.kibana_user_data.rendered
}

resource "aws_lb_target_group_attachment" "es_data" {
  for_each         = module.es_data_nodes
  target_group_arn = local.es_target_group_arn
  target_id        = each.value.id
  port             = 9200
}

resource "aws_lb_target_group_attachment" "es_master" {
  for_each         = module.es_master_nodes
  target_group_arn = local.es_target_group_arn
  target_id        = each.value.id
  port             = 9200
}

resource "aws_lb_target_group_attachment" "kibana" {
  target_group_arn = local.kibana_target_group_arn
  target_id        = module.es_kibana_node.id
  port             = 5601
}

resource "aws_ebs_volume" "es_data_nodes" {
  for_each          = toset(var.azs)
  availability_zone = each.key
  size              = 100
  encrypted         = true
  tags = {
    Name = "es-data-${index(var.azs, each.value) + 1}-data-volume"
  }
}

resource "aws_volume_attachment" "ebs_attachment" {
  for_each    = { for idx, az in var.azs : idx => az }
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.es_data_nodes[each.value].id
  instance_id = module.es_data_nodes[each.key].id
}