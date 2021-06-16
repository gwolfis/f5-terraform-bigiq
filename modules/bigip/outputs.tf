# BIG-IP Management Public IP Addresses
output "mgmt_public_ips" {
  description = "List of BIG-IP public IP addresses for the management interfaces"
  value       = aws_eip.mgmt[*].public_ip
}

# BIG-IP Management Public DNS
output "mgmt_public_dns" {
  description = "List of BIG-IP public DNS records for the management interfaces"
  value       = aws_eip.mgmt[*].public_dns
}

# BIG-IP Management Port
output "mgmt_port" {
  description = "HTTPS Port used for the BIG-IP management interface"
  value       = length(var.vpc_public_subnet_ids) > 0 ? "443" : "8443"
}

# Public Network Interface
output "public_nic_ids" {
  description = "List of BIG-IP public network interface ids"
  value       = aws_network_interface.public[*].id
}

output "mgmt_addresses" {
  description = "List of BIG-IP management addresses"
  value       = aws_network_interface.mgmt[*].private_ips
}

output "public_addresses" {
  description = "List of BIG-IP public addresses"
  value       = aws_network_interface.public[*].private_ips
}

output "private_addresses" {
  description = "List of BIG-IP private addresses"
  value       = aws_network_interface.private[*].private_ips
}

output "bigip_data" {
  value = <<EOF
  
      mgmt_priv_ips   : ${join(",", aws_network_interface.mgmt.private_ips)}
      mgmt_pub_ips    : ${join(",", aws_network_interface.mgmt.public_ips)}
      mgmt_public_dns : ${join(",", aws_eip.mgmt.public_dns)}
      mgmt_url        : https://${element(aws_eip.mgmt.public_dns, 0)}:8443
      aws_secret_name : ${aws_secretsmanager_secret.bigip.name}
    EOF
}