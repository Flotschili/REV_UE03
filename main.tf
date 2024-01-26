###########################################
# backend
###########################################
terraform {
  backend "s3" {
    bucket = "flos-git-ref-bucket-01"
    key    = "rev-demo.tf"
    region = "us-east-1"
  }
}

###########################################
# provider
###########################################

provider "aws" {
  region = "us-east-1"
}

provider "local" {
}

provider "tls" {
}

###########################################
# locals
###########################################

locals {
  webserver_ami           = "ami-0b5eea76982371e91"
  webserver_instance_type = "t2.micro"
  webserver_key_name      = "webserver-key-pair"
}

###########################################
# data
###########################################

data "aws_iam_instance_profile" "webserver_instance_profile_git" {
  name = "LabInstanceProfile"
}

###########################################
# resources
###########################################

resource "aws_security_group" "webserver_secg_git" {
  name = "webserver-secg_git"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "webserver_key_pair_git" {
  key_name   = local.webserver_key_name
  public_key = tls_private_key.rsa_git.public_key_openssh
}

resource "tls_private_key" "rsa_git" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "webserver_key_git" {
  content  = tls_private_key.rsa_git.private_key_pem
  filename = local.webserver_key_name
}




resource "aws_instance" "webserver_instance_git" {
  depends_on = [
    aws_key_pair.webserver_key_pair_git
  ]

  ami                    = local.webserver_ami
  instance_type          = local.webserver_instance_type
  vpc_security_group_ids = ["${aws_security_group.webserver_secg_git.id}"]

  key_name = aws_key_pair.webserver_key_pair_git.key_name

  iam_instance_profile = data.aws_iam_instance_profile.webserver_instance_profile_git.name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              usermod -a -G apache ec2-user
              echo "<html><body><h1>Hello World from $(hostname -f)</h1></body></html>" > /var/www/html/index.html
            EOF

  tags = {
    Name = "webserver"
  }
}

###########################################
# output 
###########################################

output "public_ip" {
  value = aws_instance.webserver_instance_git.public_ip
}

output "url" {
  value = "http://${aws_instance.webserver_instance_git.public_ip}"
}

output "ssh-command" {
  value = "sudo ssh ec2-user@${aws_instance.webserver_instance_git.public_ip} -i ${aws_key_pair.webserver_key_pair_git.key_name}"
}
