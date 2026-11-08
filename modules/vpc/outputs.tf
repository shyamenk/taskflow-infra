output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The unique identifier of the project VPC."
}

output "public_subnet_ids" {
  description = "List of IDs corresponding to the public subnets."
  value       = toset(aws_subnet.public[*].id)
}

output "private_subnet_ids" {
  description = "List of IDs corresponding to the private subnets."
  value       = toset(aws_subnet.private[*].id)
}

output "internet_gateway_id" {
  description = "The unique identifier of the internet gateway attached to the VPC."
  value       = aws_internet_gateway.igw.id
}
