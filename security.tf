resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "ec2_security_group" {
  ingress = [
    {
      description      = ""
      from_port        = 0
      to_port          = 65535
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
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