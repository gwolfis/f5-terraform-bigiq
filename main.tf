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
  secret_string = var.user_password
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
# Create Management Network Interfaces
#
resource "aws_network_interface" "mgmt" {
  count           = length(var.vpc_mgmt_subnet_ids)
  subnet_id       = var.vpc_mgmt_subnet_ids[count.index]
  security_groups = var.mgmt_subnet_security_group_ids

  tags = {
    Name        = format("%s-mgmt-intf-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

#
# add an elastic IP to the BIG-IP management interface
#
resource "aws_eip" "mgmt" {
  count             = var.mgmt_eip ? length(var.vpc_mgmt_subnet_ids) : 0
  network_interface = aws_network_interface.mgmt[count.index].id
  vpc               = true

  tags = {
    Name        = format("%s-mgmt-eip-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

# 
# Create Public Network Interfaces
#
resource "aws_network_interface" "public" {
  count             = length(var.vpc_public_subnet_ids)
  subnet_id         = var.vpc_public_subnet_ids[count.index]
  security_groups   = var.public_subnet_security_group_ids
  private_ips_count = var.application_endpoint_count

  tags = {
    Name        = format("%s-pub-intf-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

# 
# Create Private Network Interfaces
#
resource "aws_network_interface" "private" {
  count           = length(var.vpc_private_subnet_ids)
  subnet_id       = var.vpc_private_subnet_ids[count.index]
  security_groups = var.private_subnet_security_group_ids

  tags = {
    Name        = format("%s-priv-intf-%s", var.owner, random_id.id.hex)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

#
# Deploy BIG-IP
#
resource "aws_instance" "f5_bigip" {
  # determine the number of BIG-IPs to deploy
  count                = var.f5_instance_count
  //count                = length(local.setup.aws.azs
  instance_type        = var.ec2_instance_type
  ami                  = var.f5_ami
  iam_instance_profile = aws_iam_instance_profile.bigip_profile.name
  key_name             = var.ec2_key_name
  monitoring           = true
  subnet_id            = module.vpc.public_subnets[0]
  user_data = data.template_file.bigip_do_tpl.rendered
  //user_data            = data.template_file.user_data_bigip.rendered
  
  vpc_security_group_ids = [
    module.security.web_server_sg,
    module.security.web_server_secure_sg,
    module.security.ssh_secure_sg,
    module.security.bigip_mgmt_secure_sg
  ]

  root_block_device {
    delete_on_termination = true
  }

  # set the mgmt interface 
  dynamic "network_interface" {
    for_each = length(aws_network_interface.mgmt) > count.index ? toset([aws_network_interface.mgmt[count.index].id]) : toset([])

    content {
      network_interface_id = network_interface.value
      device_index         = 0
    }
  }

  # set the public interface only if an interface is defined
  dynamic "network_interface" {
    for_each = length(aws_network_interface.public) > count.index ? toset([aws_network_interface.public[count.index].id]) : toset([])

    content {
      network_interface_id = network_interface.value
      device_index         = 1
    }
  }


  # set the private interface only if an interface is defined
  dynamic "network_interface" {
    for_each = length(aws_network_interface.private) > count.index ? toset([aws_network_interface.private[count.index].id]) : toset([])

    content {
      network_interface_id = network_interface.value
      device_index         = 2
    }
  }
  
  # build user_data file from template
  //user_data = templatefile(
    //"${path.module}/f5_onboard2.tpl",
      //{
      //user_name     = var.user_name
      //user_password = var.user_password
      //secrets_id    = aws_secretsmanager_secret.bigip.id
      //targethost    = join(",", aws_network_interface.mgmt.*.private_ip)
      //targetsshkey  = var.targetsshkey
      //bigiq_mgmt_ip = var.bigiq_mgmt_ip
      //onboard_log   = var.onboard_log
      //}
  //)

  depends_on = [aws_eip.mgmt]

  tags = {
    Name        = format("%s-f5-bigip-%s-%d", var.owner, random_id.id.hex, count.index)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
    Role        = "bigip"
    CWLogGroup  = format("%s-f5-bigip-cloudwatch-lg-%s", var.owner, random_id.id.hex)
    CWLogStream = format("%s-f5-bigip-cloudwatch-ls-%s", var.owner, random_id.id.hex)
  }
}

data "template_file" "bigip_do_tpl" {
  template = file("${path.module}/do-bigiq.tpl")

  vars = {
    user_name     = var.user_name 
    user_password = var.user_password
    //targethost     = aws_instance.f5_bigip[0].private_ip
    targethost    = join(",", aws_network_interface.mgmt.*.private_ip)
    targetsshkey  = var.ec2_key_name
  }
}

# Run REST API for configuration
resource "local_file" "bigip_do_file" {
  content  = data.template_file.bigip_do_tpl.rendered
  filename = "${path.module}/${var.rest_bigip_do_file}"
}

# resource "null_resource" "bigip01_DO" {
#   depends_on = [aws_instance.f5_bigip]
#   # Running DO REST API
#   provisioner "local-exec" {
#     command = <<-EOF
#       #!/bin/bash
#       sleep 180
#       curl -ks -X POST https://${var.bigiq_mgmt_ip}${var.rest_do_uri} -u ${var.user_name}:${var.user_password} -d @${var.rest_bigip_do_file}
#       x=1; while [ $x -le 30 ]; do STATUS=$(curl -s -k -X GET https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task -u ${var.user_name}:${var.user_password}); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
#       sleep 10
#     EOF
#   }
# }

resource "null_resource" "bigip01_DO" {
  depends_on = [aws_instance.f5_bigip]
  # Running DO REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!bin/bash
      sleep 300
      json=$(curl -ks -X POST -d '{"username": '${var.user_name}', "password": '${var.user_password}', "loginProviderName":"local"}' https://${var.bigiq_mgmt_ip}/mgmt/shared/authn/login)
      token=$(echo $json-onboard | jq -r '.token.token')
      echo $token
      onboard=$(curl -ks -X POST -H "X-F5-Auth-Token: $token" https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding -d @${var.rest_bigip_do_file})
      echo $onboard | jq
      taskid=$(echo $onboard | jq -r '.id')
      echo $taskid >> taskid.txt
      x=1; while [ $x -le 30 ]; do STATUS=$(curl -s -k -X GET -H "X-F5-Auth-Token: $token" https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
      sleep 10
    EOF
  }
}

resource "aws_cloudwatch_log_group" "f5_bigip_cloudwatch_lg" {
  name = format("%s-f5-bigip-cloudwatch-lg-%s", var.owner, random_id.id.hex)

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_cloudwatch_log_stream" "f5_bigip_cloudwatch_ls" {
  name           = format("%s-f5-bigip-cloudwatch-ls-%s", var.owner, random_id.id.hex)
  log_group_name = aws_cloudwatch_log_group.f5_bigip_cloudwatch_lg.name
}

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