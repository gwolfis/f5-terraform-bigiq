# AWS
variable "region" { default = "eu-central-1"}
variable "environment" { default = "aws"}
variable "owner" { default = "tf-aws-demo"}
variable "ec2_key_name" { default = "CE-lab-wolfis"}
variable "azs" {
  type = list (string)
  default = ["eu-central-1b", "eu-central-1b", "eu-central-1c"]
}

variable "cidr_bigip" {default = "10.0.0.0/16"}
#variable "subnet_id" {}

# BIG-IP
variable "f5_instance_count" {
  description = "Number of BIG-IPs to deploy"
  type        = number
  default     = 1
}

variable "f5_ami" { default = "ami-0a5d51f7188d4507f"}
variable "f5_ami_search_name" {
  description = "BIG-IP AMI name to search for"
  type        = string
  default     = "F5 Networks BIGIP-15.* PAYG - Best 25Mbps*"
}

variable "user_name" { default = "admin"}
variable "user_password" { default = ""}
variable "onboard_log" { default = "/var/log/startup-script.log" }
variable "tenant" { default = "Team_A"}
variable "application" { default = "App_1"}

variable "displayname" {default = "NGINX Demo WebServer"}

# BIG-IQ
variable "vpc_bigiq" { default = "vpc-08063432f7480473e"}
variable "cidr_bigiq" { default = "10.42.0.0/16"}
variable "rtb_bigiq" {default = "rtb-0cd4e1c999b2544b8"}

#BIG-IQ DO vars
variable "targetsshkey" { default = "blabla.pem"}
variable "bigiq_mgmt_ip"  { default= ""}
variable "rest_bigip_do_file" { default= "bigip_do_data.json"}

# Taken from module.bigip
variable "application_endpoint_count" {
  description = "number of public application addresses to assign"
  type        = number
  default     = 2
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type"
  type        = string
  default     = "m4.large"
}

variable "vpc_public_subnet_ids" {
  description = "AWS VPC Subnet id for the public subnet"
  type        = list
  default     = []
}

variable "vpc_private_subnet_ids" {
  description = "AWS VPC Subnet id for the private subnet"
  type        = list
  default     = []
}

variable "vpc_mgmt_subnet_ids" {
  description = "AWS VPC Subnet id for the management subnet"
  type        = list
  default     = []
}

variable "mgmt_eip" {
  description = "Enable an Elastic IP address on the management interface"
  type        = bool
  default     = true
}

variable "mgmt_subnet_security_group_ids" {
  description = "AWS Security Group ID for BIG-IP management interface"
  type        = list
  default     = []
}

variable "public_subnet_security_group_ids" {
  description = "AWS Security Group ID for BIG-IP public interface"
  type        = list
  default     = []
}

variable "private_subnet_security_group_ids" {
  description = "AWS Security Group ID for BIG-IP private interface"
  type        = list
  default     = []
}