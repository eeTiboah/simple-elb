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

resource "aws_launch_configuration" "asg-launch-configuration" {
    image_id = data.aws_ami.my_ami.id
    instance_type = "t2.micro"
    security_groups = [ aws_security_group.app-sg.id ]
    associate_public_ip_address = true
    user_data = <<EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd.x86_64
                systemctl start httpd.service
                systemctl enable httpd.service
                echo "Hello World, this is Emmanuel at $(hostname -f)" > /var/www/html/index.html
                EOF
                
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "app-asg" {
    name= "Application-ASG"
    launch_configuration = aws_launch_configuration.asg-launch-configuration.name
    vpc_zone_identifier = data.aws_subnet_ids.default-subnets.ids
    min_size = 2
    max_size = 10
    tag {
      key = "Name"
      value = "${var.env_prefix}-ASG"
      propagate_at_launch = true
    }

}

resource "aws_security_group" "elb-sg" {
  name = "Load-Balancer-security-group"
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
  }
}

resource "aws_lb" "app-lb" {
    name = "Application-load-balancer"
    subnets = [data.aws_subnet_ids.default-subnets.id]
    load_balancer_type = "application"
    security_groups = [aws_security_group.elb-sg.id]

}

resource "aws_lb_listener" "app-lb-listener" {
  load_balancer_arn = aws_lb.app-lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page not found"
      status_code = 404
    }
  }
}



resource "aws_lb_target_group" "elb-target-group" {
    name = "Server-target-group"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default-vpc.id

    health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
    }
}

