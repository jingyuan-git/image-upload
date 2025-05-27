# 检查是否存在 Web 应用私有子网
data "aws_subnets" "existing_web_subnet" {
  filter {
    name   = "cidr-block"
    values = [var.private_subnet_web_cidr]
  }
  filter {
    name   = "vpc-id"
    values = [var.work_vpc_id]
  }
}

# 检查是否存在 RDS AZ1 私有子网
data "aws_subnets" "existing_rds_az1_subnet" {
  filter {
    name   = "cidr-block"
    values = [var.private_subnet_rds_cidr_az1]
  }
  filter {
    name   = "vpc-id"
    values = [var.work_vpc_id]
  }
}

# 检查是否存在 RDS AZ2 私有子网
data "aws_subnets" "existing_rds_az2_subnet" {
  filter {
    name   = "cidr-block"
    values = [var.private_subnet_rds_cidr_az2]
  }
  filter {
    name   = "vpc-id"
    values = [var.work_vpc_id]
  }
}

# 条件创建：Web 应用私有子网
resource "aws_subnet" "private_subnet_web" {
  count = length(data.aws_subnets.existing_web_subnet.ids) == 0 ? 1 : 0
  
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_web_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for Web Application"
  }
}

# 条件创建：RDS AZ1 私有子网
resource "aws_subnet" "private_subnet_rds_az1" {
  count = length(data.aws_subnets.existing_rds_az1_subnet.ids) == 0 ? 1 : 0
  
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_rds_cidr_az1
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for RDS in AZ1"
  }
}

# 条件创建：RDS AZ2 私有子网
resource "aws_subnet" "private_subnet_rds_az2" {
  count = length(data.aws_subnets.existing_rds_az2_subnet.ids) == 0 ? 1 : 0
  
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_rds_cidr_az2
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for RDS in AZ2"
  }
}

# 查找现有的工作公共子网
data "aws_subnet" "work_public_subnet" {
  filter {
    name   = "tag:Name"
    values = ["Work Public Subnet"]
  }
  filter {
    name   = "vpc-id"
    values = [var.work_vpc_id]
  }
}

# 检查是否存在第二个公共子网
data "aws_subnets" "existing_public_az2_subnet" {
  filter {
    name   = "cidr-block"
    values = ["10.0.4.0/24"]  # 根据你的实际 CIDR 调整
  }
  filter {
    name   = "vpc-id"
    values = [var.work_vpc_id]
  }
}


# Local 变量用于统一引用子网 ID
locals {
  private_subnet_web_id     = length(data.aws_subnets.existing_web_subnet.ids) > 0 ? data.aws_subnets.existing_web_subnet.ids[0] : aws_subnet.private_subnet_web[0].id
  private_subnet_rds_az1_id = length(data.aws_subnets.existing_rds_az1_subnet.ids) > 0 ? data.aws_subnets.existing_rds_az1_subnet.ids[0] : aws_subnet.private_subnet_rds_az1[0].id
  private_subnet_rds_az2_id = length(data.aws_subnets.existing_rds_az2_subnet.ids) > 0 ? data.aws_subnets.existing_rds_az2_subnet.ids[0] : aws_subnet.private_subnet_rds_az2[0].id
  public_subnet_az2_id = length(data.aws_subnets.existing_public_az2_subnet.ids) > 0 ? data.aws_subnets.existing_public_az2_subnet.ids[0] : aws_subnet.public_subnet_az2[0].id
}

# RDS 子网组（使用 local 变量）
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [
    local.private_subnet_rds_az1_id,
    local.private_subnet_rds_az2_id
  ]

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Web 安全组
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = var.work_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web SG"
  }
}

# NAT Gateway EIP
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "NAT Gateway EIP"
  }
}

# NAT Gateway（使用 local 变量）
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.work_public_subnet.id  # 使用公共子网而不是私有子网
  tags = {
    Name = "NAT Gateway"
  }
}

# 私有路由表
resource "aws_route_table" "private_route_table" {
  vpc_id = var.work_vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# 私有子网路由表关联（使用 local 变量）
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = local.private_subnet_web_id
  route_table_id = aws_route_table.private_route_table.id
}

# 条件创建：第二个公共子网
resource "aws_subnet" "public_subnet_az2" {
  count = length(data.aws_subnets.existing_public_az2_subnet.ids) == 0 ? 1 : 0
  
  vpc_id                  = var.work_vpc_id
  cidr_block              = "10.0.4.0/24"  # 根据你的实际 CIDR 调整
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet AZ2"
  }
}

# Local 变量用于第二个公共子网
locals {
  public_subnet_az2_id = length(data.aws_subnets.existing_public_az2_subnet.ids) > 0 ? data.aws_subnets.existing_public_az2_subnet.ids[0] : aws_subnet.public_subnet_az2[0].id
}

# ALB（使用 local 变量）
resource "aws_lb" "this" {
  name               = "image-upload-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [
    data.aws_subnet.work_public_subnet.id,
    local.public_subnet_az2_id
  ]
  security_groups    = [aws_security_group.web_sg.id]

  tags = {
    Name = "Image Upload ALB"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.work_vpc_id

  tags = {
    Name = "Web Target Group"
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}