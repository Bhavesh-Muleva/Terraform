# var 
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env {}
variable access_key {}
variable secret_key {}
variable my_ip {}
# variable ssh_public_key {}

# AWS Provider
provider "aws" {
    region = "ap-south-1"
    access_key = var.access_key
    secret_key = var.secret_key 
}

# VPC
resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env}-vpc"
    }
}

# SUBNET
resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env}-subnet-1"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name: "${var.env}-igw"
    }
}

# Route_Table
resource "aws_default_route_table" "myapp-route-table" {
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name: "${var.env}-rtb"
    }
}

# route_table_association 
resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_default_route_table.myapp-route-table.id
}

# security group
resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env}-default-sg"
    }
}

#data block to get latest ami image available
data "aws_ami" "latest-amazon-image" {
    most_recent = true
    owners = ["amazon"]
    
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-*-x86_64-gp2"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-image.id
}

# resource "aws_key_pair" "ssh-key" {
#     key_name = "linux-machine"
#     public_key = var.ssh_public_key
# }
resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-image.id
    instance_type = "t2.micro"

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id] 
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = "linux-machine"

    user_data = <<EOF
                    #!/bin/bash
                    sudo yum update -y && sudo yum install -y docker
                    sudo systemctl start docker
                    sudo useradd -aG docker ec2-user
                    docker run -p 8080:80 nginx
                EOF

    tags = {
        Name: "${var.env}-server"
    }
}