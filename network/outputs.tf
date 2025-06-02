output "private_subnet_web_id" {
  description = "The ID of the private subnet for Web Application"
  value       = aws_subnet.private_subnet_web.id
}

output "private_subnet_web2_id" {
  description = "The ID of the private subnet for Web Application"
  value       = aws_subnet.private_subnet_web2.id
}


output "security_group_web_sg_id" {
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
    aws_subnet.private_subnet_rds_az1.id,
    aws_subnet.private_subnet_rds_az2.id
  ]
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.nat.id
}

output "web_target_group_arn" {
  description = "The ARN of the web target group"
  value       = aws_lb_target_group.web.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the Application Load Balancer"
  value       = aws_lb.this.zone_id
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda_security_group.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds_security_group.id
}