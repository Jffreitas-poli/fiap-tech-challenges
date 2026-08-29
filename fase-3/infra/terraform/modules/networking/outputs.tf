output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR da VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas (ordenadas por AZ)."
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas (ordenadas por AZ)."
  value       = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]
}

output "nat_public_ips" {
  description = "IPs publicos dos NAT Gateways."
  value       = [for e in aws_eip.nat : e.public_ip]
}
