
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------
# Networking: VPC & Subnets
# -------------------------
resource "aws_vpc" "riz" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "riz-vpc"
  }
}

# Public subnets
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.riz.id
  cidr_block              = var.subnet1_cidr
  map_public_ip_on_launch = var.public_subnets_map_public_ip
  availability_zone       = var.public_subnet1_az

  tags = {
    Name = "public-subnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.riz.id
  cidr_block              = var.subnet2_cidr
  map_public_ip_on_launch = var.public_subnets_map_public_ip
  availability_zone       = var.public_subnet2_az

  tags = {
    Name = "public-subnet2"
  }
}

# Private subnets
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.riz.id
  cidr_block        = var.subnet3_cidr
  availability_zone = var.private_subnet1_az

  tags = {
    Name = "private-subnet1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.riz.id
  cidr_block        = var.subnet4_cidr
  availability_zone = var.private_subnet2_az

  tags = {
    Name = "private-subnet2"
  }
}

resource "aws_subnet" "private_subnet3" {
  vpc_id            = aws_vpc.riz.id
  cidr_block        = var.subnet5_cidr
  availability_zone = var.private_subnet3_az

  tags = {
    Name = "private-subnet3"
  }
}

resource "aws_subnet" "private_subnet4" {
  vpc_id            = aws_vpc.riz.id
  cidr_block        = var.subnet6_cidr
  availability_zone = var.private_subnet4_az

  tags = {
    Name = "private-subnet4"
  }
}

# -------------------------
# Internet Gateway & Routes
# -------------------------
resource "aws_internet_gateway" "riz_gateway" {
  vpc_id = aws_vpc.riz.id

  tags = {
    Name = "riz-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.riz.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.riz_gateway.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

# -------------------------
# Security Groups
# -------------------------
# Web tier SG (80/443 from anywhere, 22 from allowed CIDRs)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP/HTTPS (and SSH from allowed CIDRs)"
  vpc_id      = aws_vpc.riz.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Restrict SSH; default is 0.0.0.0/0 but you can override via variable
  dynamic "ingress" {
    for_each = var.ssh_allowed_cidrs
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# DB SG: allow MySQL from web_sg only
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL from web security group"
  vpc_id      = aws_vpc.riz.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

resource "aws_security_group_rule" "db_ingress_from_web" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.web_sg.id
  description              = "MySQL from web-sg"
}

# -------------------------
# EC2 Instances (Web Tier)
# -------------------------
resource "aws_instance" "ecomm" {
  ami                         = var.ami_id
  instance_type               = var.web_instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  subnet_id                   = aws_subnet.public_subnet1.id
  associate_public_ip_address = true
  user_data                   = file(var.ecomm_user_data)

  tags = {
    Name = "EC2-1"
  }
}

resource "aws_instance" "food" {
  ami                         = var.ami_id
  instance_type               = var.web_instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  subnet_id                   = aws_subnet.public_subnet2.id
  associate_public_ip_address = true
  user_data                   = file(var.food_user_data)

  tags = {
    Name = "EC2-2"
  }
}

# -------------------------
# Application Load Balancer
# -------------------------
resource "aws_lb" "external_alb" {
  name               = "external-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  tags = {
    Name = "external-alb"
  }
}

resource "aws_lb_target_group" "target_elb" {
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.riz.id

  health_check {
    path     = "/health"
    port     = "80"
    protocol = "HTTP"
  }

  tags = {
    Name = "alb-tg"
  }
}

resource "aws_lb_target_group_attachment" "ecomm" {
  target_group_arn = aws_lb_target_group.target_elb.arn
  target_id        = aws_instance.ecomm.id
  port             = 80

  depends_on = [
    aws_lb_target_group.target_elb,
    aws_instance.ecomm,
  ]
}

resource "aws_lb_target_group_attachment" "food" {
  target_group_arn = aws_lb_target_group.target_elb.arn
  target_id        = aws_instance.food.id
  port             = 80

  depends_on = [
    aws_lb_target_group.target_elb,
    aws_instance.food,
  ]
}

resource "aws_lb_listener" "listener_elb" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_elb.arn
  }
}

# -------------------------
# RDS (MySQL)
# -------------------------
resource "aws_db_subnet_group" "rds_subnet" {
  name = "rds-subnet"
  subnet_ids = [
    aws_subnet.private_subnet1.id,
    aws_subnet.private_subnet2.id
  ]

  tags = {
    Name = "Db subnet group"
  }
}

resource "aws_db_instance" "rds" {
  allocated_storage      = var.db_allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet.name
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  multi_az               = var.db_multi_az
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = var.db_skip_final_snapshot
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Optional: storage type, backup settings, etc., can be added here.
  tags = {
    Name = "mysql-rds"
  }
}
