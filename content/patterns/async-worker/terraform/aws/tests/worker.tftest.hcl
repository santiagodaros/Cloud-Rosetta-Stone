# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  name                = "worker-test"
  results_bucket_name = "worker-test-results-001"
  image_uri           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/worker:1.0.0"
}

run "visibility_timeout_is_six_times_function_timeout" {
  command = plan

  variables {
    function_timeout_seconds = 90
  }

  assert {
    condition     = aws_sqs_queue.jobs.visibility_timeout_seconds == 540
    error_message = "El visibility timeout tiene que ser 6× el timeout de la función."
  }
}

run "dlq_outlives_source_queue" {
  command = plan

  assert {
    condition     = aws_sqs_queue.dlq.message_retention_seconds > aws_sqs_queue.jobs.message_retention_seconds
    error_message = "La DLQ tiene que retener más que la cola de origen."
  }
}

run "partial_batch_and_bounded_concurrency" {
  command = plan

  assert {
    condition     = contains(aws_lambda_event_source_mapping.jobs.function_response_types, "ReportBatchItemFailures")
    error_message = "Hace falta ReportBatchItemFailures."
  }

  assert {
    condition     = aws_lambda_event_source_mapping.jobs.scaling_config[0].maximum_concurrency == 10
    error_message = "La concurrencia tiene que estar acotada en el event source mapping."
  }
}

run "rejects_concurrency_below_two" {
  command = plan

  variables {
    max_concurrency = 1
  }

  expect_failures = [var.max_concurrency]
}

run "rejects_timeout_over_lambda_limit" {
  command = plan

  variables {
    function_timeout_seconds = 1200
  }

  expect_failures = [var.function_timeout_seconds]
}
