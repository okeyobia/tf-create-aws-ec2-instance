
provider "aws" {
  region     = "us-east-1"
  
}
# resource "aws_instance" "my_instance" {
#   ami           = "ami-083654bd07b5da81d"
#   instance_type = "t2.micro"  

#   vpc_security_group_ids = [aws_security_group.sg-instance.id]

#   user_data = <<-EOF
#     #!/bin/bash
#     echo "Hello World" > index.html
#     nohup busybox httpd -f -p ${var.server_port} &
#     EOF

#   tags = {
#     "Name" = "tf-instance-test"
#   }
# }

data "aws_vpc" "default_vpc" {
    default = true
}

data "aws_subnet_ids" "default_subnets" {
    vpc_id = data.aws_vpc.default_vpc.id  
}

resource "aws_launch_configuration" "aws_launch_instance" {
    image_id = "ami-083654bd07b5da81d"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.sg-instance.id] 

    user_data = <<-EOF
    #!/bin/bash
    echo "Hello World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

    # Required when using a launch configuration with an auto scaling group.
    # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
    lifecycle {
        create_before_destroy = true
    }

}

resource "aws_autoscaling_group" "asg_tf" {
    # availability_zones = ["us-east-1a"]
  
    launch_configuration = aws_launch_configuration.aws_launch_instance.name
    vpc_zone_identifier = data.aws_subnet_ids.default_subnets.ids
    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

    # desired_capacity = 1
    max_size = 10
    min_size = 2
    tag {
        key = "Name"
        value = "tf-asg-eg"
        propagate_at_launch = true    
    }
}

resource "aws_lb" "tf_load_balancer" {
    name = "tf-asg-load-balancer"
    # internal = true
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.default_subnets.ids
    security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.tf_load_balancer.arn
  port = 80
  protocol = "HTTP"

  # By default, returns a simple 404 page.lifecycle {
    default_action {
        type = "fixed-response"
        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = "404"
        }
    }
}


resource "aws_security_group" "alb" {
  name = "tf_alb_security_group"
  description = "tf_alb_security_group"

  # Allow all inbound traffic
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow all outbound traffic
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default_vpc.id

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

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    condition {
        path_pattern {
            values = ["*"] 
        }
        
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = number
  default = 8080
}

output "alb_dns_name" {
    value = aws_lb.tf_load_balancer.dns_name
    description = "The domain name of the load balancer"
}
  

resource "aws_security_group" "sg-instance" {
  name        = "terraform-security-group-instance"
  description = "Used for accepting inbound traffic"

  ingress {
    protocol    = "tcp"
    from_port   = var.server_port
    to_port     = var.server_port
    cidr_blocks = ["0.0.0.0/0"]
  
    }
}


  
