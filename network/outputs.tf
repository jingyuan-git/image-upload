output "private_subnet_web_id" {
  description = "The ID of the private subnet for Web Application"
  value       = aws_subnet.private_subnet_web[0].id
}


output "security_group_id" {
  description = "The ID of the web security group"
  value       = aws_security_group.web_sg.id
}

output "db_subnet_group_name" {
  description = "The name of the DB subnet group"
  value       = aws_db_subnet_group.rds_subnet_group.name
}

output "private_subnet_rds_ids" {
  description = "The IDs of the private subnets for RDS"
  value       = [
    aws_subnet.private_subnet_rds_az1[0].id,
    aws_subnet.private_subnet_rds_az2[0].id
  ]
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.nat.id
}