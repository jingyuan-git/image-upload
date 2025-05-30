
output "instance_public_ip" {
  value = module.ec2.instance_public_ip
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = module.rds.rds_endpoint
}

output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = module.network.alb_dns_name
}

output "load_balancer_url" {
  description = "The complete URL of the Application Load Balancer"
  value       = "http://${module.network.alb_dns_name}"
}

output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = module.s3_bucket.bucket_name
}