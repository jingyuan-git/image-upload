variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "vockey"
}

variable "work_vpc_id" {
  description = "Work VPC ID"
  type        = string
  default = "vpc-0bf8c2b7c832a6fb9"
}

variable "db_user" {
  description = "The username for the RDS database"
  type        = string
  default = "root"
}

variable "db_password" {
  description = "The password for the RDS database"
  type        = string
  default = "password123"
}

variable "google_api_key" {
  description = "Google API key for Lambda annotation function"
  type        = string
}

# variable "subnet_id" {
#   description = "Subnet ID"
#   type        = string
# }

# variable "vpc_security_group_ids" {
#   description = "List of security group IDs"
#   type        = list(string)
# }

# variable "iam_instance_profile" {
#   description = "IAM instance profile name"
#   type        = string
# }