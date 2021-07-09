#
# Ensure Secret exists
#
data "aws_secretsmanager_secret" "password" {
  name = var.aws_secretmanager_secret_id
}

#
# Find BIG-IP AMI
#
# data "aws_ami" "f5_ami" {
#   most_recent = true
#   owners      = ["679593333241"]

#   filter {
#     name   = "name"
#     values = ["ami-0a5d51f7188d4507f"]
#   }
# }

# 
# Create Management Network Interfaces
#
resource "aws_network_interface" "mgmt" {
  count           = length(var.vpc_mgmt_subnet_ids)
  subnet_id       = var.vpc_mgmt_subnet_ids[count.index]
  security_groups = var.mgmt_subnet_security_group_ids

  tags = {
    Name        = format("%s-mgmt-intf-%s", var.owner, var.random_id)
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
    Name        = format("%s-mgmt-eip-%s", var.owner, var.random_id)
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
    Name        = format("%s-pub-intf-%s", var.owner, var.random_id)
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
    Name        = format("%s-priv-intf-%s", var.owner, var.random_id)
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
  #subnet_id            = module.vpc.public_subnets
  
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
    for_each = toset([aws_network_interface.mgmt[count.index].id])

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
    //"${path.module}/startup-script.tpl",
      //{
      //admin_user     = var.admin_user
      //admin_password = var.admin_password
      #targethost     = "${join(",", flatten(module.bigip.mgmt_addresses))}"
      #targethost     = aws_network_interface.mgmt[0].private_ips
      #targethost    = join(",", aws_network_interface.mgmt.*.private_ip)
      #targethost     = module.bigip.*.private_addresses[0]["mgmt_private"]["private_ip"][0]
      //targetsshkey   = var.targetsshkey
      //bigiq_mgmt_ip  = var.bigiq_mgmt_ip
      //}
  //)

  depends_on = [aws_eip.mgmt]

  tags = {
    Name        = format("%s-f5-bigip-%s-%d", var.owner, var.random_id, count.index)
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
    Role        = "bigip"
    CWLogGroup  = format("%s-f5-bigip-cloudwatch-lg-%s", var.owner, var.random_id)
    CWLogStream = format("%s-f5-bigip-cloudwatch-ls-%s", var.owner, var.random_id)
  }
}

# data "template_file" "bigip_do_json" {
#   template = file("${path.module}/do-bigiq.json")
  
#   vars = {
#     admin_user     = var.user_name 
#     admin_password = var.user_password
#     targethost     = aws_network_interface.mgmt[0].private_ip
#     targetsshkey   = var.targetsshkey
#   }
# }

# # Run REST API for configuration
# resource "local_file" "bigip_do_file" {
#   content  = data.template_file.bigip_do_json.rendered
#   filename = "${path.module}/${var.rest_bigip_do_file}"
# }

# resource "null_resource" "bigip01_DO" {
#   depends_on = [aws_instance.f5_bigip]
#   # Running DO REST API
#   provisioner "local-exec" {
#     command = <<-EOF
#       #!/bin/bash
#       sleep 420
#       curl -ks -X ${var.rest_do_method} https://${var.bigiq_mgmt_ip}${var.rest_do_uri} -u ${var.user_name}:${var.user_password} -d @${var.rest_bigip_do_file}
#       x=1; while [ $x -le 30 ]; do STATUS=$(curl -s -k -X GET https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task -u ${var.user_name}:${var.user_password}); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
#       sleep 10
#     EOF
#   }
# }

resource "aws_cloudwatch_log_group" "f5_bigip_cloudwatch_lg" {
  name = format("%s-f5-bigip-cloudwatch-lg-%s", var.owner, var.random_id)

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_cloudwatch_log_stream" "f5_bigip_cloudwatch_ls" {
  name           = format("%s-f5-bigip-cloudwatch-ls-%s", var.owner, var.random_id)
  log_group_name = aws_cloudwatch_log_group.f5_bigip_cloudwatch_lg.name
}
