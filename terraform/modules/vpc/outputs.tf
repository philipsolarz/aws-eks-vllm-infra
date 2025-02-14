output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "private_subnets" {
  description = "List of private subnets."
  value       = aws_subnet.private_zones[*].id
}
