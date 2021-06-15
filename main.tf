terraform {
  required_version = "~> 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">3.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">2.3.0"
    }
    template = {
      source  = "hashicorp/template"
      version = ">2.1.2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">2.1.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
  }
}

provider "aws" {
  region = var.region
}

#
# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

#
# Create Secret Store and Store BIG-IP Password
#
resource "aws_secretsmanager_secret" "bigip" {
  name = format("%s-bigip-secret-%s", var.owner, random_id.id.hex)

  tags = {
    Name        = format("%s-bigip-secret-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}
resource "aws_secretsmanager_secret_version" "bigip-pwd" {
  secret_id     = aws_secretsmanager_secret.bigip.id
  secret_string = var.admin_password
}

#
# Create the VPC 
#
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                 = format("%s-vpc-%s", var.owner, random_id.id.hex)
  cidr                 = var.cidr_bigip
  enable_dns_hostnames = true
  enable_dns_support   = true

  azs = var.azs

  public_subnets = [
    for num in range(length(var.azs)) :
    cidrsubnet(var.cidr_bigip, 8, num)
  ]

  vpc_tags = {
    Name        = format("%s-vpc-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }

  public_subnet_tags = {
    Name        = format("%s-pub-subnet-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }

  public_route_table_tags = {
    Name        = format("%s-pub-rt-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }

  igw_tags = {
    Name        = format("%s-igw-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

# VPC Peering
resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id   = var.vpc_bigiq
  vpc_id        = module.vpc.vpc_id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between BIG-IP and BIG-IQ"
  }
}

resource "aws_vpc" "bigip" {
  cidr_block = var.cidr_bigip
}

resource "aws_vpc" "vpc_bigiq" {
  cidr_block = var.cidr_bigiq
}


# Set Peering Routes
data "aws_route_table" "bigip" {
  vpc_id     = module.vpc.vpc_id 
  subnet_id  = module.vpc.public_subnets[0]
  depends_on = [module.vpc]
}

resource "aws_route" "from_bigip_to_bigiq" {
  route_table_id            = data.aws_route_table.bigip.id
  destination_cidr_block    = var.cidr_bigiq
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  depends_on                = [data.aws_route_table.bigip]
}

resource "aws_route" "from_bigiq_to_bigip" {
  route_table_id            = var.rtb_bigiq
  destination_cidr_block    = var.cidr_bigip
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

#
# Create necessary security groups
#
module security {
  source = "./modules/security"

  owner       = var.owner
  environment = var.environment
  random_id   = random_id.id.hex
  vpc_id      = module.vpc.vpc_id
}

#
# Create BIG-IP
#
module bigip {
  source = "./modules/bigip"

  owner       = var.owner
  environment = var.environment
  random_id   = random_id.id.hex

  //f5_instance_count           = length(local.setup.aws.azs)
  f5_instance_count           = var.f5_instance_count
  ec2_key_name                = var.ec2_key_name
  aws_secretmanager_secret_id = aws_secretsmanager_secret.bigip.id

  mgmt_subnet_security_group_ids = [
    module.security.web_server_sg,
    module.security.web_server_secure_sg,
    module.security.ssh_secure_sg,
    module.security.bigip_mgmt_secure_sg
  ]

  vpc_mgmt_subnet_ids = module.vpc.public_subnets
  f5_ami_search_name  = var.f5_ami_search_name
}

# data "template_file" "startup_script" {
#   template = "${file("${path.module}/startup-script.tpl")}"
#   vars = {
#     admin_user     = var.admin_user 
#     admin_password = var.admin_password
#     targethost     = "${join(",", flatten(module.bigip.mgmt_addresses))}"
#     targetsshkey   = var.targetsshkey
#     bigiq_mgmt_ip  = var.bigiq_mgmt_ip
#     }
# }

# data "template_file" "bigip_do_json" {
#   template = file("${path.module}/do-bigiq.json")
  
#   vars = {
#     admin_user     = var.admin_user 
#     admin_password = var.admin_password
#     targethost     = "${join(",", flatten(module.bigip.mgmt_addresses))}"
#     targetsshkey   = var.targetsshkey
#   }
#   depends_on = [module.bigip]
# }

# # Run REST API for configuration
# resource "local_file" "bigip_do_file" {
#   depends_on = [module.bigip]
#   content  = data.template_file.bigip_do_json.rendered
#   filename = "${path.module}/bigip.do.json"
# }

# resource "null_resource" "bigip01_DO" {
#   depends_on = [module.bigip]
#   # Running DO REST API
#   provisioner "local-exec" {
#     command = <<-EOF
#       #!bin/bash
#       sleep 420
#       json=$(curl -ks -X POST -d '{"username": '${var.admin_user}', "password": '${var.admin_password}', "loginProviderName":"local"}' https://${var.bigiq_mgmt_ip}/mgmt/shared/authn/login)
#       token=$(echo $json | jq -r '.token.token')
#       echo $token
#       onboard=$(curl -ks -X POST -H "X-F5-Auth-Token: $token" https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding -d @do-bigiq.json)
#       echo $onboard | jq
#       taskid=$(echo $onboard | jq -r '.id' )
#       #echo $taskid
#       #x=1; while [ $x -le 30 ]; do STATUS=$(curl -s -k -X GET -H "X-F5-Auth-Token: $token" https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task/$taskid); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
#       #sleep 10
#     EOF
#   }
# }

# resource "null_resource" "bigip01_DO" {
#   depends_on = [module.bigip]
#   # Running DO REST API
#   provisioner "local-exec" {
#     command = <<-EOF
#       #!bin/bash
#       #sleep 420
#       curl -ks -X POST https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding -u ${var.admin_user}:${var.admin_password} -d @${var.rest_bigip_do_file}
#       x=1; while [ $x -le 30 ]; do STATUS=$(curl -s -k -X GET https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task -u ${var.admin_user}:${var.admin_password}); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
#       sleep 10
#     EOF
#   }
# }

#
# Create Autodiscovery WebServers
#
module webserver {
  source = "./modules/webserver"

  owner        = var.owner
  environment  = var.environment
  random_id    = random_id.id.hex
  subnet_id    = element(module.vpc.public_subnets, 0)
  ec2_key_name = var.ec2_key_name
  color        = ["ff5e13", "0072bb"]
  color_tag    = ["orange", "blue"]
  server_count = 2

  sec_group_ids = [
    module.security.web_server_sg,
    module.security.web_server_secure_sg
  ]

  tenant              = var.tenant
  application         = var.application
  server_display_name = var.displayname
  autodiscovery       = "true"
}