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

#variable "f5_ami" { default = "ami-0a5d51f7188d4507f"}
variable "f5_ami_search_name" {
  description = "BIG-IP AMI name to search for"
  type        = string
  default     = "F5 Networks BIGIP-15.* PAYG - Best 25Mbps*"
}

variable "admin_user" { default = "admin"}
variable "admin_password" { default = ""}

variable "tenant" { default = "Team_A"}
variable "application" { default = "App_1"}

variable "displayname" {default = "NGINX Demo WebServer"}

# BIG-IQ
variable "vpc_bigiq" { default = "vpc-08063432f7480473e"}
variable "cidr_bigiq" { default = "10.42.0.0/16"}
variable "rtb_bigiq" {default = "rtb-0cd4e1c999b2544b8"}

#BIG-IQ DO vars
variable "targetsshkey" { default = "CE-lab-wolfis.pem"}
variable "bigiq_mgmt_ip"  { default= "10.42.1.92"}
variable "rest_do_method" { default= "POST"}
variable "rest_do_uri" { default= "/mgmt/shared/declarative-onboarding"}
variable "rest_bigip_do_file" { default= "bigip_do_data.json"}
