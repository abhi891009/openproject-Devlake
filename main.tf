#Cloud Provider
provider "aws" {
  region = "eu-west-1"
}

# VPC Module
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "OpenProject-VPC"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "Public-Subnet"
  }
}

# Public Subnet in a different Availability Zone
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1b"
  tags = {
    Name = "Public-Subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group with dynamic block
resource "aws_security_group" "instance_sg" {
  name   = "instance-sg"
  vpc_id = aws_vpc.main.id
  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2-SG"
  }
}

resource "aws_lb"  "app_lb_open" {
  name               = "openproject-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]
}

# ALB for DevLake
resource "aws_lb" "app_lb" {
  name               = "devlake-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]
}

# ALB Target Groups
resource "aws_lb_target_group" "openproject_tg" {
  name     = "openproject-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "devlake_tg" {
  name     = "devlake-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# ALB Listener & Rules for OpenProject
resource "aws_lb_listener" "listener_openproject" {
  load_balancer_arn = aws_lb.app_lb_open.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.openproject_tg.arn
  }
}

# ALB Listener & Rules for DevLake
resource "aws_lb_listener" "listener_devlake" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.devlake_tg.arn
  }
}

# EC2 Instance - OpenProject
resource "aws_instance" "openproject" {
  ami           = "ami-0df368112825f8d8f"
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  user_data = <<-EOT
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              docker run -dit -p 80:80 -e OPENPROJECT_SECRET_KEY_BASE=secret -e OPENPROJECT_HOST__NAME=0.0.0.0:80 -e OPENPROJECT_HTTPS=false openproject/community:12
              EOT

  tags = merge(var.tags, {
    Name = "${lookup(var.tags, "Name", "default")}-OpenProject"
  })
}

# EC2 Instance - DevLake
resource "aws_instance" "devlake" {
  ami           = "ami-0df368112825f8d8f"
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOT
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              git clone https://github.com/lavanya24072000/usecases.git
              cd usecases
              curl -SL https://github.com/docker/compose/releases/download/v2.33.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              docker-compose up -d
              EOT

  tags = merge(var.tags, {
    Name = "${lookup(var.tags, "Name", "default")}-DevLake"
  })
}

# Register Targets
resource "aws_lb_target_group_attachment" "openproject_attachment" {
  target_group_arn = aws_lb_target_group.openproject_tg.arn
  target_id        = aws_instance.openproject.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "devlake_attachment" {
  target_group_arn = aws_lb_target_group.devlake_tg.arn
  target_id        = aws_instance.devlake.id
  port             = 4000
}