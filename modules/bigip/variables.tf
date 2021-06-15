#BIG-IQ DO vars
variable "targetsshkey"       { default = "CE-lab-wolfis.pem"}
variable "bigiq_mgmt_ip"      { default= "10.42.1.92"}
variable "rest_bigip_do_file" { default= "bigip_do_data.json"}
variable "admin_user"         { default= "admin"}
variable "admin_password"     { default= ""}

variable "owner" {
  description = "Owner for resources created by this module"
  type        = string
  default     = "terraform-aws-bigip-demo"
}

variable "environment" {
  description = "Environment tag for resources created by this module"
  type        = string
  default     = "demo"
}

variable "random_id" {
  description = "A random id used for the name wihtin tags"
  type        = string
}

variable "f5_ami" {
  description = "BIG-IP AMI ID"
  type        = string
  default = "ami-0a5d51f7188d4507f"
}

variable "f5_ami_search_name" {
  description = "BIG-IP AMI name to search for"
  type        = string
}

variable "f5_instance_count" {
  description = "Number of BIG-IPs to deploy"
  type        = number
  default     = 1
}

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
variable "ec2_key_name" {
  description = "AWS EC2 Key name for SSH access"
  type        = string
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

variable "aws_secretmanager_secret_id" {
  description = "AWS Secret Manager Secret ID that stores the BIG-IP password"
  type        = string
}