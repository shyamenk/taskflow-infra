output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The unique identifier of the project VPC."
}

output "public_subnet_ids" {
  description = "List of IDs corresponding to the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs corresponding to the private subnets."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT gateways, one per availability zone."
  value       = aws_nat_gateway.nat_gw[*].id
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables, one per availability zone."
  value       = aws_route_table.private_rt[*].id
}

output "internet_gateway_id" {
  description = "The unique identifier of the internet gateway attached to the VPC."
  value       = aws_internet_gateway.igw.id
}
