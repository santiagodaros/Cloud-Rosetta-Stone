output "queue_url" {
  description = "URL de la cola de trabajos (los productores necesitan sqs:SendMessage)."
  value       = aws_sqs_queue.jobs.id
}

output "dlq_url" {
  description = "URL de la dead-letter queue."
  value       = aws_sqs_queue.dlq.id
}

output "results_bucket" {
  description = "Bucket de resultados."
  value       = aws_s3_bucket.results.bucket
}
