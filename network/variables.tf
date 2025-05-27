variable "work_vpc_id" {
  description = "The ID of the existing Work VPC"
  type        = string
}

variable "private_subnet_web_cidr" {
  description = "CIDR block for the private subnet used by Web Application"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_rds_cidr_az1" {
  description = "CIDR block for the private subnet used by RDS in AZ1"
  type        = string
  default     = "10.0.12.0/24"
}

variable "private_subnet_rds_cidr_az2" {
  description = "CIDR block for the private subnet used by RDS in AZ2"
  type        = string
  default     = "10.0.13.0/24"
}

variable "availability_zone_1" {
  description = "First availability zone for the subnets"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_2" {
  description = "Second availability zone for the subnets"
  type        = string
  default     = "us-east-1b"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}