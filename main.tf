provider "aws" {
  region = "us-east-1"
}

# Generate SSH Keys for Control Server and Web/DB Servers
resource "tls_private_key" "control_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_private_key" "web_db_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create Key Pairs in AWS using the public keys generated above
resource "aws_key_pair" "control_key" {
  key_name   = "control_key"
  public_key = tls_private_key.control_key.public_key_openssh
}

resource "aws_key_pair" "web_db_key" {
  key_name   = "web_db_key"
  public_key = tls_private_key.web_db_key.public_key_openssh
}

# VPC Setup
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Ans-Terr-VPC"
  }
}

# Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Private Subnet"
  }
}

# Internet Gateway and Route Table for Public Subnet
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Internet Gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group for Web and DB Servers
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main_vpc.id

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
    Name = "Web Security Group"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_ip" {
  vpc = true
}

# NAT Gateway in Public Subnet
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_ip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "NAT Gateway"
  }
}

# Route Table for Private Subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Web Server EC2 Instances (2 instances)
resource "aws_instance" "web_server" {
  count                  = 2
  ami                    = "ami-005fc0f236362e99f" # Ubuntu AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.web_db_key.key_name # Using web/db key for web servers
  tags = {
    Name = "Web Server ${count.index + 1}"
  }
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2 wget unzip
              wget -O /tmp/2137_barista_cafe.zip https://tooplate.com/zip-templates/2137_barista_cafe.zip
              unzip /tmp/2137_barista_cafe.zip -d /tmp/
              cp -r /tmp/2137_barista_cafe/* /var/www/html/
              systemctl enable apache2
              systemctl start apache2
              EOF
}

# DB Server EC2 Instance
resource "aws_instance" "db_server" {
  ami                    = "ami-005fc0f236362e99f" # Ubuntu AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.web_db_key.key_name # Using web/db key for db server
  tags = {
    Name = "DB Server"
  }
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y mysql-server
              systemctl enable mysql
              systemctl start mysql
              EOF
}

# Control Server EC2 Instance for Ansible
resource "aws_instance" "control_server" {
  ami                    = "ami-005fc0f236362e99f" # Ubuntu AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.control_key.key_name # Using control key for control server
  tags = {
    Name = "Control Server"
  }
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y software-properties-common
              apt-add-repository ppa:ansible/ansible
              apt-get update -y
              apt-get install -y ansible
              EOF
}

# Outputs
output "web_server_1_ip" {
  value = aws_instance.web_server[0].public_ip
}

output "web_server_2_ip" {
  value = aws_instance.web_server[1].public_ip
}

output "db_server_ip" {
  value = aws_instance.db_server.public_ip
}

output "control_server_ip" {
  value = aws_instance.control_server.public_ip
}
