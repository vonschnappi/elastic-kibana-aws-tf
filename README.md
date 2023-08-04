# Terraform module for creating Elasticsearch and Kibana in AWS

This repo contains a module that creates an Elasticsearch cluster with kibana [latest version](https://www.elastic.co/guide/en/elasticsearch/reference/current/es-release-notes.html). It relies on Terraform for provisioning resources and user-data for configuration.

## Resources created
* VPC
    * VPC CIDR 10.0.0.0/16
    * 3 public subnets
    * 3 private subnets
    * nat gateway for each private subnet
* Network Loadbalancer
    * Deployed in three AZs, in each private subnet using network mapping
    * Listener on 9200 for elastic nodes
    * Target group on 9200 for elastic nodes 
    * Listener on 5601 for kibana
    * Target group on 5601 for kibana
* Jumper server
    * One jumper server deployed in a public subnet
    * Security group allowing SSH access to jumper from the public internet
    * SSH key saved in secrets manager under `ssh/jumper_key`
* Elastic cluster
    * Three master nodes
    * Three data nodes
    * Security group allowing ssh access and elastic service ports from jumper
    * SSH key saved in secrets manager under `ssh/es_key`
* Kibana instance
    * One kibana instance
    * Security group allowing ssh access and kibana service port from jumper
    * SSH key saved in secrets manager under `ssh/kibana_key`

## Deployment
AWS recently [changed IAM role trust policy behavior](https://aws.amazon.com/blogs/security/announcing-an-update-to-iam-role-trust-policy-behavior/). When creating an IAM role, the trust policy should explicitly mention the role itself. However, this is [currently not possible with Terraform](https://github.com/hashicorp/terraform-provider-aws/issues/27034). The problem is that when Terrform tries to create the role, it first tries to create the trust policy. But that fails because the trust policy references a non-existing role. Bit of chicken and egg problem. To overcome the issue, you should first create the jumper and es roles without the role referenced in the trust policy. Then you can add the role ARN to the trust policy and run the complete apply:

### Targeted creation of IAM role
```hcl
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
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}
```

`terraform apply --target='module.elastic_cluster.aws_iam_role.es_node'`

Then add the role to the list of principals:
```hcl
"Principal": {
    "Service": "ec2.amazonaws.com",
    "AWS": "arn:aws:iam::${var.account_id}:role/es-node"
},
```

Repeat for `resource "aws_iam_role" "jumper_server"`

### Deploy all
Once you have created the roles, you can go ahead and deploy using `terraform apply`.

## Accessing kibana
NLB and compute resources (Elasticsearch nodes, kibana instance) are all deployed in private subnets with the excpetion of the jumper server. Being deployed in private subnet means that there's no access to them from the public internet. Accessing kibana UI can be done using SSH tunneling:
1. Get the jumper key from secrets manager and save it in ~/.ssh as jumper.pem. 
2. Run `sudo chmod 400 jumper.pem`
3. Run `ssh -i "jumper.pem" -L 5601:[KIBANA_PRIVATE_IP]:5601 ubuntu@[JUMPER_DNS_NAME]`
4. Open a browser and navigate to [http://localhost:5601]()

