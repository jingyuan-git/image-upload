output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.image_caption_db.endpoint
}

output "rds_username" {
  description = "The username for the RDS instance"
  value       = aws_db_instance.image_caption_db.username
}