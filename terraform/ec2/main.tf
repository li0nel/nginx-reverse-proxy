data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "http" "icanhazip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = "t2.nano"
  key_name                    = aws_key_pair.generated.key_name
  vpc_security_group_ids      = [aws_security_group.ec2_security_group.id]
  subnet_id                   = var.vpc.public_subnets.0.id
  iam_instance_profile        = aws_iam_instance_profile.vm_profile.name
}

resource "aws_security_group" "ec2_security_group" {
  name   = "${var.stack_name}-ec2"
  vpc_id = var.vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 2376
    to_port     = 2376
    cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "vm_profile" {
  name = "vm_profile_${var.stack_name}"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "ec2_role_${var.stack_name}"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ec2_role_policy" {
  name = "ec2-policy-${var.stack_name}"
  role = aws_iam_role.role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "logs:*"
         ],
         "Resource": [
            "*"
         ]
      }
  ]
}
EOF
}

locals {
  public_key_filename  = "./key-${var.stack_name}.pub"
  private_key_filename = "./key-${var.stack_name}"
}

resource "tls_private_key" "default" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated" {
  depends_on = [tls_private_key.default]
  key_name   = "key-${var.stack_name}"
  public_key = tls_private_key.default.public_key_openssh
}

resource "local_file" "public_key_openssh" {
  depends_on = [tls_private_key.default]
  content    = tls_private_key.default.public_key_openssh
  filename   = local.public_key_filename
}

resource "local_file" "private_key_pem" {
  depends_on = [tls_private_key.default]
  content    = tls_private_key.default.private_key_pem
  filename   = local.private_key_filename
}

resource "null_resource" "chmod" {
  depends_on = [local_file.private_key_pem]

  provisioner "local-exec" {
    command = "chmod 400 ${local.private_key_filename}"
  }
}