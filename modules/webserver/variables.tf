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

variable "subnet_id" {
  description = "The id of the target subnets"
  type        = string
}

variable "sec_group_ids" {
  description = "The ids of the target security groups"
  type        = list(string)
}

variable "ec2_key_name" {
  description = "The name of the SSH key to use for the EC2 instances"
  type        = string
}

variable "server_count" {
  description = "The number of webservers"
  type        = number
}

variable "color" {
  description = "The background color of the website hosted by the webserver"
  type        = list(string)
}

variable "color_tag" {
  description = "EC2 tag to pinpoint the color of the website running in the webservers"
  type        = list(string)
}

variable "tenant" {
  description = "The Big-IP tenant that will manage this server"
  type        = string
}

variable "application" {
  description = "The Big-IP application that will expose this server"
  type        = string
}

variable "server_display_name" {
  description = "The display name of the server visible on the homepage"
  default     = "AWS Demo WebServer"
  type        = string
}

variable "autodiscovery" {
  description = "AWS tag to enable auto-discovery"
  default     = "true"
  type        = string
}
