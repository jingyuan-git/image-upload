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
  default = "vpc-0ffaab53cbf6939e8"
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