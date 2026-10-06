# Worker asíncrono con escala a cero — AWS
#
# Lambda disparada por SQS con respuestas parciales de lote, DLQ con retención
# mayor que la cola de origen y resultados en S3. Sin claves: el execution role
# de la función es la identidad.

data "aws_partition" "current" {}

locals {
  # AWS recomienda visibility timeout >= 6× el timeout de la función.
  visibility_timeout_seconds = var.function_timeout_seconds * 6
  results_prefix             = "results/"
}

# --- Colas ----------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  name                    = "${var.name}-jobs-dlq"
  sqs_managed_sse_enabled = true
  # Máximo (14 días): en colas Standard el vencimiento cuenta desde que el mensaje
  # entró a la cola original (gotcha: dlq-retention-original-timestamp).
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "jobs" {
  name                       = "${var.name}-jobs"
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = local.visibility_timeout_seconds
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Solo la cola de trabajos puede usar esta DLQ.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.jobs.arn]
  })
}

# --- Bucket de resultados -------------------------------------------------------

resource "aws_s3_bucket" "results" {
  #checkov:skip=CKV_AWS_21:Resultados regenerables con TTL; versioning duplicaría costo (ver patrón object-storage-ttl).
  #checkov:skip=CKV_AWS_144:Replicación cross-region no aplica a resultados regenerables.
  #checkov:skip=CKV_AWS_18:Access logging fuera de alcance; usar CloudTrail data events si se requiere.
  #checkov:skip=CKV2_AWS_62:Notificaciones de eventos fuera de alcance del patrón.
  bucket = var.results_bucket_name
}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket                  = aws_s3_bucket.results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "results" {
  bucket = aws_s3_bucket.results.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "results" {
  #checkov:skip=CKV2_AWS_67:Clave administrada por AWS (aws/s3).
  bucket = aws_s3_bucket.results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "results" {
  bucket = aws_s3_bucket.results.id

  rule {
    id     = "expire-results"
    status = "Enabled"
    filter {
      prefix = local.results_prefix
    }
    expiration {
      days = var.results_ttl_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# --- Identidad de la función ----------------------------------------------------

resource "aws_iam_role" "worker" {
  name = "${var.name}-worker"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_managed" {
  for_each = toset([
    "service-role/AWSLambdaBasicExecutionRole",
    "AWSXRayDaemonWriteAccess",
  ])
  role       = aws_iam_role.worker.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

resource "aws_iam_role_policy" "worker" {
  name = "consume-jobs-write-results"
  role = aws_iam_role.worker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = aws_sqs_queue.jobs.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.results.arn}/${local.results_prefix}*"
      },
    ]
  })
}

# --- Lambda + event source mapping ----------------------------------------------

resource "aws_cloudwatch_log_group" "worker" {
  #checkov:skip=CKV_AWS_158:Cifrado con la clave administrada por CloudWatch; CMK opcional.
  name              = "/aws/lambda/${var.name}-worker"
  retention_in_days = 365
}

resource "aws_lambda_function" "worker" {
  #checkov:skip=CKV_AWS_115:La concurrencia se limita en el event source mapping (scaling_config), no con reserved concurrency (gotcha: max-concurrency-protects-downstream).
  #checkov:skip=CKV_AWS_116:Invocación síncrona desde SQS: la DLQ vive en la cola, no en la función.
  #checkov:skip=CKV_AWS_117:Sin VPC: SQS y S3 se acceden por sus endpoints de AWS; ver private-web-api para red privada.
  #checkov:skip=CKV_AWS_173:Variables de entorno sin secretos; cifradas con la clave administrada por Lambda.
  #checkov:skip=CKV_AWS_272:Code signing no aplica a funciones empaquetadas como imagen.
  function_name = "${var.name}-worker"
  role          = aws_iam_role.worker.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  timeout       = var.function_timeout_seconds
  memory_size   = 512

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      RESULTS_BUCKET = aws_s3_bucket.results.bucket
      RESULTS_PREFIX = local.results_prefix
    }
  }

  depends_on = [aws_cloudwatch_log_group.worker, aws_iam_role_policy_attachment.worker_managed]
}

resource "aws_lambda_event_source_mapping" "jobs" {
  event_source_arn                   = aws_sqs_queue.jobs.arn
  function_name                      = aws_lambda_function.worker.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = 5

  # Solo los mensajes que fallaron vuelven a la cola (gotcha: partial-batch-failures).
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = var.max_concurrency
  }
}
