locals {
  cloud_hippie_api_image = "${var.image_name}"
  repository_url = "cloud-hippie-api"
}

# We need a cluster in which to put our service.
resource "aws_ecs_cluster" "this" {
  name = "cloud-hippie-main-cluster"
}

data "aws_ecr_repository" "this" {
  name = "cloud-hippie-ecr-repository"
}

# Log groups hold logs from our app.
resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/${var.api_name}"
}

# The main service.
resource "aws_ecs_service" "this" {
  name            = "${var.api_name}"
  task_definition = aws_ecs_task_definition.this.arn
  cluster         = aws_ecs_cluster.this.id
  launch_type     = "FARGATE"

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.this_http.arn
    container_name   = "${var.api_name}"
    container_port   = "3000"
  }

  network_configuration {
    assign_public_ip = true

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id,
    ]

    subnets = [
      aws_subnet.public_d.id,
      aws_subnet.public_e.id,
    ]
  }
}

# The task definition for our app.
resource "aws_ecs_task_definition" "this" {
  family = "${var.api_name}"
  container_definitions = jsonencode(
  [
    {
      name = var.api_name
    image = "${data.aws_ecr_repository.this.repository_url}:${var.api_name}@${var.api_version}"
      portMappings = [
        {
          containerPort = 3000
        }
      ]
    logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region" : "us-east-1"
          "awslogs-group":  "/ecs/${var.api_name}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ])
  execution_role_arn = aws_iam_role.task_execution_role.arn

  # These are the minimum values for Fargate containers.
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]

  # This is required for Fargate containers (more on this later).
  network_mode = "awsvpc"
}

# Normally we'd prefer not to hardcode an ARN in our Terraform, but since this is an AWS-managed
# policy, it's okay.
data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the above policy to the execution role.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}

resource "aws_lb_target_group" "this_http" {
  name        = "${var.api_name}-target-group"
  port        = 3000
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.app_vpc.id
  

  health_check {
    enabled = true
    path    = "/"
  }


  depends_on = [aws_internet_gateway.igw]
}



resource "aws_alb" "this" {
  name               = "${var.api_name}-lb"
  internal           = false
  load_balancer_type = "application"


  subnets = [
    aws_subnet.public_d.id,
    aws_subnet.public_e.id,
  ]

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]

  depends_on = [aws_internet_gateway.igw]
}


resource "aws_alb_listener" "this_http" {
  load_balancer_arn = aws_alb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# resource "aws_alb_listener" "this_https" {
#   load_balancer_arn = aws_alb.this.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   certificate_arn   = aws_acm_certificate.this.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.this_http.arn
#   }

#   depends_on = [
#     aws_acm_certificate.this,
#   ]
# }

output "alb_url" {
  value = "http://${aws_alb.this.dns_name}"
}

resource "aws_acm_certificate" "this" {
  domain_name       = "${var.api_name}.cloudhippie.net"
  validation_method = "DNS"
}


output "domain_validations" {
  value = aws_acm_certificate.this.domain_validation_options
}
