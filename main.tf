resource "aws_vpc" "vpc1" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc1.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "art1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "art2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "terasg" {
  name        = "terasg"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc1.id

  tags = {
    Name = "terasg"
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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

resource "aws_s3_bucket" "example" {
  bucket = "akashterras3bucket2024project"

  tags = {
    Name        = "my bucket"
    Environment = "dev"
  }

}

resource "aws_instance" "webserver1" {
  ami                    = "ami-0cd59ecaf368e5ccf"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.terasg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("script1.sh"))

}
resource "aws_instance" "webserver2" {
  ami                    = "ami-0cd59ecaf368e5ccf"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.terasg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("script2.sh"))

}
#create alb
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.terasg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    name = "web"
  }
}
#create lb target group
resource "aws_lb_target_group" "tg" {
  name     = "mytg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc1.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}
#attach instances with the target group
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80

}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80

}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }

}
#print the lb dns on the terminal (incase u dont have acess to the console)
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name

}