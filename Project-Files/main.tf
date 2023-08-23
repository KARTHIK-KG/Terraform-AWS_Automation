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
region = "us-east-1"
access_key = "<access-key>"
secret_key = "<secret-key>"
}

# VPC Network
resource "aws_vpc" "kg-vpc" {
  cidr_block = "10.0.0.0/16"
    tags = {
    Name = "production-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "kg-gw" {
  vpc_id = aws_vpc.kg-vpc.id
  tags = {
    Name = "production-gw"
  }
}

# Route Table
resource "aws_route_table" "kg-route-table" {
  vpc_id=aws_vpc.kg-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kg-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.kg-gw.id
  }

  tags = {
    Name = "production-route-table"
  }
}

# Subnet
resource "aws_subnet" "kg-subnet" {
  vpc_id = aws_vpc.kg-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prodution-subnet"
  }
  
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.kg-subnet.id
  route_table_id = aws_route_table.kg-route-table.id
}

# Security Group (Ports: 22,80,443)
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.kg-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

    ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

    ingress {
    description      = "SSH"
    from_port        = 2
    to_port          = 2
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Netowork Interface 
resource "aws_network_interface" "kg-ni" {
  subnet_id       = aws_subnet.kg-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}

# Elastic IP
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.kg-ni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.kg-gw ]
}

# ubuntu server with apache2 
resource "aws_instance" "ubuntu-server" {
  ami           ="ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "kg-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.kg-ni.id
  }
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl start apache2
  sudo bash -c 'echo hi > /var/www/html/index.html'
  EOF
  tags = {
    Name="web-server"
  }
}


# resource "aws_subnet" "subnet-1" {
#   vpc_id     = aws_vpc.first-aws-vpc.id
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "production-subnet"
#   }
# }

# resource "aws_instance" "my-first-server" {
#   ami           ="ami-053b0d53c279acc90"
#   instance_type = "t2.micro"

#   tags = {
#     Name = "ubuntu-server-1"
#   }
# }

# ----------------

# resource "<provider>_<resource_type>" "name" {
#     config options...
#     key="value"
#     key2="another val"
#     }


