locals {
  user_data = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install unzip

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    aws secretsmanager get-secret-value --secret-id ssh/es_key --query SecretString --output text >> ~/.ssh/es.pem
    sudo chmod 400 ~/.ssh/es.pem

    aws secretsmanager get-secret-value --secret-id ssh/kibana_key --query SecretString --output text >> ~/.ssh/kibana.pem
    sudo chmod 400 ~/.ssh/kibana.pem

  EOT
}

module "jumper_key_pair" {
  source             = "terraform-aws-modules/key-pair/aws"
  key_name           = var.key_name
  create_private_key = true
}

resource "aws_secretsmanager_secret" "jumper_key" {
  name = "ssh/jumper_key"
}

resource "aws_secretsmanager_secret_version" "jumper_key" {
  secret_id     = aws_secretsmanager_secret.jumper_key.id
  secret_string = module.jumper_key_pair.private_key_pem
}

module "jumper_security_group" {

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.jumper_security_group_name
  description = "Security group for jumper server"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = join(",", formatlist("%s/32", "77.137.70.15"))
    }
  ]
  egress_rules = ["all-all"]
}

resource "aws_iam_policy" "jumper_server" {
  name = "jumper_server"
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

resource "aws_iam_role" "jumper_server" {
  name = "jumper-server"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com",
                "AWS": "arn:aws:iam::${var.account_id}:role/jumper-server"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "jumper_policy_attach" {
  role       = aws_iam_role.jumper_server.name
  policy_arn = aws_iam_policy.jumper_server.arn
}

resource "aws_iam_instance_profile" "jumper_server" {
  name = "jumper_server"
  role = aws_iam_role.jumper_server.name
}

module "jumper" {
  source = "terraform-aws-modules/ec2-instance/aws"
  ami    = var.ami

  name                   = "jumper"
  instance_type          = var.jumper_instance_type
  key_name               = var.key_name
  monitoring             = true
  vpc_security_group_ids = [module.jumper_security_group.security_group_id]
  subnet_id              = var.public_subnets[0]

  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jumper_server.name

  root_block_device = [{
    encrypted = true
  }]
  enable_volume_tags = true

  tags = {
    Terraform = "true"
    Role      = "jumper"
  }

  user_data = base64encode(local.user_data)
}

