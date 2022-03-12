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
  ami           = "ami-02f47fa62c613afb4"
  instance_type = "t2.micro"

  tags = {
    Name = var.instance_name
  }
}

