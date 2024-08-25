terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
  alias  = "home_region"
}

#ami
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  provider    = aws.home_region

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical's AWS account ID

}
# Create a VPC with public and private subnets
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "my_vpc"
    Owner       = "shirley"
    Environment = "development"
  }
  #provider = aws.home_region 
}

# Create a subnet (private subnet)
resource "aws_subnet" "my_subnet1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.192.0/19"
  availability_zone = "eu-north-1a"
  #provider = aws.home_region 
}

# Create a subnet
resource "aws_subnet" "my_subnet2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.64.0/18"
  availability_zone = "eu-north-1b"
  #provider = aws.home_region 
}

# Create a subnet
resource "aws_subnet" "my_subnet3" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.128.0/18"
  availability_zone = "eu-north-1c"
  #provider = aws.home_region 
}

# Create an Elastic ip Adress (EIP)
resource "aws_eip" "my_eip" {
}

# Create a Nat Gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.my_subnet1.id
  tags = {
    Name        = "my_nat_gateway"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name        = "my_internet_gateway"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Create a public Route table

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }

  tags = {
    Name        = "my_internet_gateway"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.my_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc1" {
  subnet_id      = aws_subnet.my_subnet3.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a private Route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }
  tags = {
    Name        = "my_internet_gateway"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Associate the private route table with the private subnets
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.my_subnet1.id
  route_table_id = aws_route_table.private_rt.id
}

# Create a Security Group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "my_lb_sg"
  description = "Security Group for the Load Balancer"
  vpc_id      = aws_vpc.my_vpc.id
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
    Name        = "my_load_balancer"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Create Load balancer
resource "aws_lb" "my_elb" {
  name               = "my-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.my_subnet2.id, aws_subnet.my_subnet3.id]
  #enable_deletion_protection = true

  tags = {
    Name        = "my_load_balancer"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Create Target group
resource "aws_lb_target_group" "my_tg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  tags = {
    Name        = "my_load_balancer"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Load balancer traffic listener
resource "aws_lb_listener" "project_lb_listener" {
  load_balancer_arn = aws_lb.my_elb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
  tags = {
    Name        = "my_load_balancer"
    Owner       = "shirley"
    Environment = "development"
  }
}

# Associate the instance with the target group
resource "aws_lb_target_group_attachment" "my_tg_attachment" {
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = aws_instance.static_webserver.id
  port             = 80
}

# Create EC2 Instance
resource "aws_instance" "static_webserver" {

  subnet_id     = aws_subnet.my_subnet1.id
  ami           = data.aws_ami.latest_ubuntu.id
  instance_type = "m5.large"
  user_data     = file("${path.module}/nginxconfig.sh")
  security_groups = [aws_security_group.project_instance_sg.id]
  tags = {
    Name        = "my_EC2"
    Owner       = "shirley"
    Environment = "development"
  }

}

# Load balancer URL

output "load_balancer_url" {
  value = aws_lb.my_elb.dns_name
}

#security group for instances
resource "aws_security_group" "project_instance_sg" {
  name     = "instance_sg"
  vpc_id   = aws_vpc.my_vpc.id
  
  #this rule allows ingress web traffic from the lb only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  #this rule allows all traffic out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]

  }
}




