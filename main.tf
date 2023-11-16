provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "epochTime_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "epochTime_subnet" {
  vpc_id            = aws_vpc.epochTime_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "epochTime_subnet2" {
  vpc_id            = aws_vpc.epochTime_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "epochTime_sg" {
  name        = "epochTime-sg"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.epochTime_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "epochTime_task_sg" {
  name        = "epochTime-task-sg"
  description = "Allow inbound traffic from ALB on port 8080"
  vpc_id      = aws_vpc.epochTime_vpc.id

  ingress {
    from_port         = 8080
    to_port           = 8080
    protocol          = "tcp"
    security_groups   = [aws_security_group.epochTime_sg.id]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }
}


resource "aws_lb" "epochTime_lb" {
  name               = "epoch-time-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.epochTime_sg.id]
  subnets            = [
    aws_subnet.epochTime_subnet.id,
    aws_subnet.epochTime_subnet2.id
  ]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "epochTime_tg" {
  name     = "epoch-time-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.epochTime_vpc.id
  target_type = "ip"

 health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "epochTime_listener" {
  load_balancer_arn = aws_lb.epochTime_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.epochTime_tg.arn
  }
}

resource "aws_internet_gateway" "epochTime_igw" {
  vpc_id = aws_vpc.epochTime_vpc.id
}

resource "aws_route_table" "epochTime_rt" {
  vpc_id = aws_vpc.epochTime_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.epochTime_igw.id
  }
}

resource "aws_route_table_association" "epochTime_rta" {
  subnet_id      = aws_subnet.epochTime_subnet.id
  route_table_id = aws_route_table.epochTime_rt.id
}

resource "aws_route_table_association" "epochTime_rta2" {
  subnet_id      = aws_subnet.epochTime_subnet2.id
  route_table_id = aws_route_table.epochTime_rt.id
}

resource "aws_ecs_cluster" "epochTime_cluster" {
  name = "epoch-time-cluster"
}

resource "aws_ecs_task_definition" "epochTime_task" {
  family                   = "epoch-time-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.epochTime_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "epoch-time-app",
      image = "fifoosab/epoch-time",
      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080
        }
      ]
    }
  ])
}

resource "aws_iam_role" "epochTime_execution_role" {
  name = "epochTime_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "epochTime_execution_role_policy" {
  role       = aws_iam_role.epochTime_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "epochTime_service" {
  name            = "epoch-time-service"
  cluster         = aws_ecs_cluster.epochTime_cluster.id
  task_definition = aws_ecs_task_definition.epochTime_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.epochTime_subnet.id,
      aws_subnet.epochTime_subnet2.id
    ]
    assign_public_ip = true
    security_groups = [aws_security_group.epochTime_task_sg.id]
  }

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.epochTime_tg.arn
    container_name   = "epoch-time-app"
    container_port   = 8080
  }
}

output "load_balancer_dns" {
  value = aws_lb.epochTime_lb.dns_name
}

output "curl_command" {
  value = "curl http://${aws_lb.epochTime_lb.dns_name}"
}

