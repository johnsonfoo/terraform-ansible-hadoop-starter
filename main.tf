terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.5"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "ap-southeast-1"
}

resource "aws_instance" "ec2_instance" {
  ami                    = "ami-02f47fa62c613afb4"
  instance_type          = "t2.micro"
  count                  = var.instance_count
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file("${var.private_key_path}")
  }

  tags = {
    Name = "${var.instance_name}-${count.index + 1}"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = file("${var.public_key_path}")
}

resource "aws_security_group" "ec2_security_group" {
  ingress = [
    {
      description      = ""
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0", ]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress {
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
