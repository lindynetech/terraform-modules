terraform {
  required_version = ">=0.13"
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

data "aws_ami" "aws_linux" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_launch_configuration" "tf-lc" {
  image_id        = data.aws_ami.aws_linux.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.web_sg.id]

  user_data = templatefile("${path.module}/user-data.sh",
    {
      server_port = var.server_port
      db_address  = data.terraform_remote_state.db.outputs.address
      db_port     = data.terraform_remote_state.db.outputs.port
    }
  )

  # Required when using a launch configuration with an auto scaling group.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "tf-asg" {
  launch_configuration = aws_launch_configuration.tf-lc.name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids
  target_group_arns    = [aws_alb_target_group.tf-alb-tg.arn]
  min_size             = var.min_size
  max_size             = var.max_size
  health_check_type    = "ELB"

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}

resource "aws_security_group" "web_sg" {
  name = "${var.cluster_name}-web-sg"
}

resource "aws_security_group_rule" "web_sg_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.web_sg.id

  cidr_blocks      = local.all_ips
  description      = "Allow server port ${var.server_port}"
  from_port        = var.server_port
  to_port          = var.server_port
  protocol         = local.tcp_protocol
  ipv6_cidr_blocks = []
  prefix_list_ids  = []
}

resource "aws_alb" "tf-alb" {
  name    = "${var.cluster_name}-tf-alb"
  subnets = data.aws_subnet_ids.default.ids
  security_groups = [aws_security_group.tf-alb-sg.id]
}

resource "aws_alb_listener" "http" {
  port              = local.http_port
  protocol          = "HTTP"
  load_balancer_arn = aws_alb.tf-alb.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "tf-alb-sg" {
  name = "${var.cluster_name}-tf-alb-sg"
}

resource "aws_security_group_rule" "tf-alb-sg-ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.tf-alb-sg.id

  cidr_blocks      = local.all_ips
  from_port        = local.http_port
  to_port          = local.http_port
  protocol         = local.tcp_protocol
  ipv6_cidr_blocks = []
  prefix_list_ids  = []
}

resource "aws_security_group_rule" "tf-alb-sg-egress" {
  type              = "egress"
  security_group_id = aws_security_group.tf-alb-sg.id

  cidr_blocks      = local.all_ips
  from_port        = local.any_port
  to_port          = local.any_port
  protocol         = local.any_protocol
  ipv6_cidr_blocks = []
  prefix_list_ids  = []
}

resource "aws_alb_target_group" "tf-alb-tg" {
  name     = "${var.cluster_name}-tf-alb-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_alb_listener_rule" "asg" {
  listener_arn = aws_alb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.tf-alb-tg.arn
  }
}

# This is for static list of EC2 instances
# resource "aws_lb_target_group_attachment" "tf-alb-tg-attachment" {}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = var.region
  }
}
