output "private_subnet_web_id" {
  description = "The ID of the private subnet for Web Application"
  value       = aws_subnet.private_subnet_web.id
}

output "private_subnet_rds_id" {
  description = "The ID of the private subnet for RDS"
  value       = aws_subnet.private_subnet_rds.id
}

output "private_subnet_rds_name" {
  description = "The name of the DB subnet group"
  value       = aws_subnet.private_subnet_rds.name
}

output "security_group_id" {
  description = "The ID of the web security group"
  value       = aws_security_group.web_sg.id
}