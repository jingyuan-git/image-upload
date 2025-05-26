variable "work_vpc_id" {
  description = "The ID of the existing Work VPC"
  type        = string
}

variable "private_subnet_web_cidr" {
  description = "CIDR block for the private subnet used by Web Application"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_rds_cidr" {
  description = "CIDR block for the private subnet used by RDS"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}