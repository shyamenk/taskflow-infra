output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The unique identifier of the project VPC."
}

output "public_subnet_ids" {
  description = "List of IDs corresponding to the public subnets."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of IDs corresponding to the private subnets."
  value       = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT gateways, one per availability zone."
  value       = [for n in aws_nat_gateway.nat_gw : n.id]
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables, one per availability zone."
  value       = [for r in aws_route_table.private_rt : r.id]
}

output "internet_gateway_id" {
  description = "The unique identifier of the internet gateway attached to the VPC."
  value       = aws_internet_gateway.igw.id
}
