
output "instance_public_ip" {
  value = module.ec2.instance_public_ip
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = module.rds.rds_endpoint
}