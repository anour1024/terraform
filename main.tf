provider "aws" {
  region  = "us-east-1"
  # The following file should contain aws_access_key_id and aws_secret_access_key keys for authentication.access_key.
  # Alternatively, you can export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables with your keys.
  shared_credentials_files = ["~/.awscred"]
}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "first-igw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create Custom Route Table
resource "aws_route_table" "prod-rt" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.first-igw.id
  }

  tags = {
    Name = "prod-rt"
  }
}

# Create Subnet
resource "aws_subnet" "first-subnet" {
  vpc_id = aws_vpc.prod-vpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "prod-subnet"
  }
}

# Create Route Table Association
resource "aws_route_table_association" "prod-association" {
    subnet_id = aws_subnet.first-subnet.id
    route_table_id = aws_route_table.prod-rt.id
  
}

# Create Security Group
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "Application port"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH connection"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

# Create Network Inteface
resource "aws_network_interface" "prod-if" {
  subnet_id = aws_subnet.first-subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}

# Create Elastic IP
resource "aws_eip" "prod-eip" {
  vpc = true
  network_interface = aws_network_interface.prod-if.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.first-igw]
}

output "server_public_ip" {
  value = aws_eip.prod-eip.public_ip
}
resource "aws_instance" "app-ec2" {
  ami = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.prod-if.id
  }
  user_data_replace_on_change = true
  user_data = <<EOF
#!/bin/bash
apt update -y
apt install docker.io mysql-server -y
EOF
  tags = {
    Name = "ec2-app"
  }
}