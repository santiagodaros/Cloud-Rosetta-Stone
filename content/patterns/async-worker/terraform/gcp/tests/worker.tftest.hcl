# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {
  mock_data "google_project" {
    defaults = { number = "123456789012" }
  }
}

variables {
  project_id          = "rosetta-test"
  name                = "worker-test"
  results_bucket_name = "worker-test-results-001"
  container_image     = "us-docker.pkg.dev/rosetta-test/worker/worker:1.0.0"
}

run "push_is_authenticated_and_internal" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.worker.ingress == "INGRESS_TRAFFIC_INTERNAL_ONLY"
    error_message = "El worker no tiene que ser público."
  }

  assert {
    condition     = length(google_pubsub_subscription.jobs.push_config[0].oidc_token) == 1
    error_message = "El push tiene que mandar un OIDC token."
  }
}

run "dead_letter_is_complete" {
  command = plan

  variables {
    max_delivery_attempts = 7
  }

  assert {
    condition     = google_pubsub_subscription.jobs.dead_letter_policy[0].max_delivery_attempts == 7
    error_message = "max_delivery_attempts no se aplica."
  }

  assert {
    condition     = google_pubsub_topic_iam_member.dead_letter_publisher.member == "serviceAccount:service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com"
    error_message = "El service agent de Pub/Sub necesita publisher en el dead-letter topic."
  }

  assert {
    condition     = google_pubsub_subscription_iam_member.source_subscriber.role == "roles/pubsub.subscriber"
    error_message = "El service agent necesita subscriber en la suscripción de origen."
  }
}

run "ack_deadline_matches_service_timeout" {
  command = plan

  variables {
    ack_deadline_seconds = 120
  }

  assert {
    condition     = google_pubsub_subscription.jobs.ack_deadline_seconds == 120 && google_cloud_run_v2_service.worker.template[0].timeout == "120s"
    error_message = "El ack deadline y el timeout del servicio tienen que coincidir."
  }

  assert {
    condition     = google_cloud_run_v2_service.worker.template[0].scaling[0].min_instance_count == 0
    error_message = "El worker tiene que escalar a cero."
  }
}

run "rejects_too_few_attempts" {
  command = plan

  variables {
    max_delivery_attempts = 3
  }

  expect_failures = [var.max_delivery_attempts]
}
