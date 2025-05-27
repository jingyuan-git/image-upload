resource "aws_subnet" "private_subnet_web" {
  vpc_id                  = var.work_vpc_id
  cidr_block              = var.private_subnet_web_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet for Web Application"
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

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "NAT Gateway EIP"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private_subnet_web.id
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

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet_web.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_lb" "this" {
  name               = "image-upload-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [
    aws_subnet.public_subnet.id,
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