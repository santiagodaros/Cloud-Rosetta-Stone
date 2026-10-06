# Web API privada Zero Trust — AWS
#
# ECS Fargate en subnets privadas (sin NAT) detrás de un ALB interno HTTPS,
# conectándose a RDS for PostgreSQL con IAM database authentication.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  private_subnets = { for i, az in var.availability_zones : az => cidrsubnet(var.vpc_cidr, 8, i) }

  # Endpoints que necesita Fargate sin salida a internet (gotcha: fargate-private-needs-endpoints).
  interface_endpoints = toset(["ecr.api", "ecr.dkr", "logs"])

  # Sin contraseña: la app genera el token con las credenciales del task role
  # (gotcha: rds-iam-connection-rate → usar pool de conexiones).
  app_environment = [
    { name = "PGHOST", value = aws_db_instance.this.address },
    { name = "PGPORT", value = "5432" },
    { name = "PGUSER", value = var.db_app_user },
    { name = "PGDATABASE", value = var.database_name },
    { name = "PGSSLMODE", value = "verify-full" },
    { name = "AWS_REGION", value = var.region },
  ]
}

# --- Red ----------------------------------------------------------------------

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow logs fuera de alcance del patrón (se cubren en el patrón de networking base).
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-${var.name}" }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "private" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "snet-${var.name}-${each.key}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "rt-${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "vpce-${var.name}-s3" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = { Name = "vpce-${var.name}-${each.key}" }
}

# --- Security groups (mínimo privilegio entre capas) --------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB interno de la API"
  vpc_id      = aws_vpc.this.id
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Tareas de ECS de la API"
  vpc_id      = aws_vpc.this.id
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "RDS PostgreSQL"
  vpc_id      = aws_vpc.this.id
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "Interface VPC endpoints"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_clients" {
  for_each          = toset(var.client_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde la red privada"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Hacia las tareas"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Desde el ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_endpoints" {
  security_group_id            = aws_security_group.app.id
  description                  = "ECR y CloudWatch Logs por interface endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoints.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_s3" {
  security_group_id = aws_security_group.app.id
  description       = "Capas de imagen de ECR en S3 (gateway endpoint)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL desde la API"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_app" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS desde las tareas"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.app.id
}

# --- ALB interno --------------------------------------------------------------

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logs fuera de alcance; requieren un bucket S3 dedicado.
  #checkov:skip=CKV2_AWS_28:WAF opcional en un ALB interno; evaluar según el modelo de amenazas.
  name                       = "${var.name}-alb"
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = [for s in aws_subnet.private : s.id]
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = true
}

resource "aws_lb_target_group" "api" {
  #checkov:skip=CKV_AWS_378:TLS termina en el ALB; el tramo ALB→tarea queda dentro de la VPC y acotado por security groups.
  name        = "${var.name}-api"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path    = var.health_check_path
    matcher = "200"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- ECS Fargate --------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  #checkov:skip=CKV_AWS_158:Cifrado con la clave administrada por CloudWatch; CMK opcional.
  name              = "/ecs/${var.name}-api"
  retention_in_days = 365
}

resource "aws_iam_role" "execution" {
  name = "${var.name}-ecs-execution"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name}-api-task"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

# Permiso para generar el token de UN usuario de base, en UNA instancia.
resource "aws_iam_role_policy" "task_rds_connect" {
  name = "rds-iam-connect"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = "arn:${data.aws_partition.current.partition}:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.this.resource_id}/${var.db_app_user}"
    }]
  })
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name                   = "api"
    image                  = var.container_image
    essential              = true
    readonlyRootFilesystem = true
    portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]
    environment            = local.app_environment
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.name}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.https, aws_vpc_endpoint.interface]
}

# --- RDS PostgreSQL con IAM auth ----------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157:Multi-AZ configurable (db_multi_az); desactivado por default por costo.
  #checkov:skip=CKV_AWS_118:Enhanced monitoring requiere un rol extra; Performance Insights cubre el diagnóstico básico.
  #checkov:skip=CKV_AWS_354:Performance Insights con la clave administrada por AWS.
  #checkov:skip=CKV2_AWS_30:Logging de queries vía parameter group, fuera de alcance del patrón.
  identifier                          = "${var.name}-db"
  engine                              = "postgres"
  engine_version                      = "17"
  instance_class                      = var.db_instance_class
  allocated_storage                   = 20
  storage_encrypted                   = true
  db_name                             = var.database_name
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  publicly_accessible                 = false
  multi_az                            = var.db_multi_az
  iam_database_authentication_enabled = true

  # Master user siempre existe: que la contraseña la genere y guarde Secrets Manager
  # (gotcha: master-password-in-secrets-manager).
  username                    = "dbadmin"
  manage_master_user_password = true

  backup_retention_period         = 7
  copy_tags_to_snapshot           = true
  deletion_protection             = true
  final_snapshot_identifier       = "${var.name}-db-final"
  auto_minor_version_upgrade      = true
  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}
