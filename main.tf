provider "aws" {
    region = "us-east-2"
}

variable "env_prefix" {
    type = string
    description = "The environment the instance is provisioned in"
}
variable "server_port" {
    type = number
    description = "The port the server will use for http requests"
    default = 8080
}

data "aws_ami" "my_ami" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = [ "amzn2-ami-hvm-*-x86_64-gp2" ]
    }
}

data "aws_vpc" "default-vpc" {
  default = true
}

data "aws_subnet_ids" "default-subnets" {
  vpc_id = data.aws_vpc.default-vpc.id
}

resource "aws_security_group" "app-sg" {
    name = "app-sg"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

