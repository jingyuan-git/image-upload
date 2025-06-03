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

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = var.work_vpc_id
  cidr_block              = "10.0.4.0/24"  # 确保不与现有子网冲突
  availability_zone       = var.availability_zone_2  # 不同的可用区
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet AZ2"
  }
}

resource "aws_subnet" "private_subnet_web" {
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_web_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for Web Application"
  }
}

resource "aws_subnet" "private_subnet_web2" {
  vpc_id                  = var.work_vpc_id
  cidr_block              = "10.0.5.0/24" 
  availability_zone       = var.availability_zone_2 
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet New"
  }
}

resource "aws_subnet" "private_subnet_rds_az1" {
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_rds_cidr_az1
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for RDS in AZ1"
  }
}

resource "aws_subnet" "private_subnet_rds_az2" {
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_rds_cidr_az2
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for RDS in AZ2"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet_rds_az1.id,
    aws_subnet.private_subnet_rds_az2.id
  ]

  tags = {
    Name = "RDS Subnet Group"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH, RDS and HTTP"
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

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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

resource "aws_security_group" "lambda_security_group" {
  name        = "lambda-security-group"
  description = "Security group for Lambda functions"
  vpc_id      = var.work_vpc_id

  # Lambda 出站流量规则（默认允许所有出站流量）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Lambda SG"
  }
}

resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Security group for RDS"
  vpc_id      = var.work_vpc_id

  ingress {
    description = "Allow Lambda access to RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.lambda_security_group.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database SG"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "NAT Gateway EIP"
  }
}

resource "aws_eip" "nat_az2" {
  domain = "vpc"
  tags = {
    Name = "NAT Gateway EIP AZ2"
  }
}


resource "aws_nat_gateway" "nat_az2" {
  allocation_id = aws_eip.nat_az2.id
  subnet_id     = aws_subnet.public_subnet_az2.id  # Public subnet in AZ2
  tags = {
    Name = "NAT Gateway AZ2"
  }
}

resource "aws_route_table" "private_route_table_az2" {
  vpc_id = var.work_vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_az2.id
  }

  tags = {
    Name = "Private Route Table AZ2"
  }
}

resource "aws_route_table_association" "private_subnet_association_az2" {
  subnet_id      = aws_subnet.private_subnet_web2.id  # Private subnet in AZ2
  route_table_id = aws_route_table.private_route_table_az2.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.work_public_subnet.id
  tags = {
    Name = "NAT Gateway"
  }
}

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

data "aws_internet_gateway" "work_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.work_vpc_id]
  }

  tags = {
    Name = "Work IGW"
  }
}

resource "aws_route_table" "public_route_table_az2" {
  vpc_id = var.work_vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.work_igw.id
  }

  tags = {
    Name = "Public Route Table AZ2"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet_web.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_lb" "this" {
  name               = "image-upload-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [
    data.aws_subnet.work_public_subnet.id,
    aws_subnet.public_subnet_az2.id
  ]
  security_groups    = [aws_security_group.web_sg.id]

  tags = {
    Name = "Image Upload ALB"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.work_vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "Web-Target-Group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
