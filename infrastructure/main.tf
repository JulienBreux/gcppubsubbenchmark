# Create project
resource "google_project" "main" {
  name       = var.gcp_project_name
  project_id = var.gcp_project_id
  org_id     = var.gcp_organization_id

  auto_create_network = false

  billing_account = var.gcp_billing_account_id
}

# Enable services
resource "google_project_service" "project" {
  count = length(var.gcp_project_services)

  project = google_project.main.id
  service = var.gcp_project_services[count.index]

  disable_dependent_services = true
}

# Organization policies
resource "google_project_organization_policy" "enforce_policies" {
  project = var.gcp_project_id

  count = length(var.gcp_project_enforce_policies)

  constraint = var.gcp_project_enforce_policies[count.index].constraint

  boolean_policy {
    enforced = var.gcp_project_enforce_policies[count.index].enforce
  }
}

resource "google_project_organization_policy" "allow_policies" {
  project = var.gcp_project_id

  count = length(var.gcp_project_allow_policies)

  constraint = var.gcp_project_allow_policies[count.index].constraint

  list_policy {
    allow {
      all = var.gcp_project_allow_policies[count.index].allow
    }
  }
}

# Create network
resource "google_compute_network" "main" {
  project = var.gcp_project_id
  name    = var.vpc_name

  auto_create_subnetworks = false

  depends_on = [
    google_project_service.project,
  ]
}

# Create sub-networks
resource "google_compute_subnetwork" "main" {
  project = var.gcp_project_id

  name          = var.vpc_subnetwork_name
  ip_cidr_range = var.vpc_subnetwork_ip_cidr_range
  region        = var.vpc_region
  network       = google_compute_network.main.id

  dynamic "secondary_ip_range" {
    for_each = var.vpc_subnetwork_secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value["range_name"]
      ip_cidr_range = secondary_ip_range.value["ip_cidr_range"]
    }
  }
}

# Default service account
resource "google_service_account" "default" {
  project = var.gcp_project_id

  account_id   = "main-service-account"
  display_name = "Main Service Account"
}

resource "google_service_account_iam_member" "wi_publisher" {
  service_account_id = google_service_account.default.name

  role   = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.gcp_project_id}.svc.id.goog[publishers/publisher]"
}

resource "google_service_account_iam_member" "wi_subscriber" {
  service_account_id = google_service_account.default.name

  role   = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.gcp_project_id}.svc.id.goog[subscribers/subscriber]"
}

resource "google_project_iam_member" "logging-log-writer" {
  project = var.gcp_project_id

  role   = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "monitoring-metric-writer" {
  project = var.gcp_project_id

  role   = "roles/monitoring.metricWriter"
  member = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "monitoring-viewer" {
  project = var.gcp_project_id

  role   = "roles/monitoring.viewer"
  member = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "stackdriver-resource-metadata-writer" {
  project = var.gcp_project_id

  role   = "roles/stackdriver.resourceMetadata.writer"
  member = "serviceAccount:${google_service_account.default.email}"
}

# resource "google_project_iam_member" "project" {
#   project = var.gcp_project_id

#   role   = "roles/pubsub.publisher"
#   member = "serviceAccount:${google_service_account.default.email}"
# }

# Create artifact registry repositories
resource "google_artifact_registry_repository" "repositories" {
  project = var.gcp_project_id

  count = length(var.artifact_registry_repositories)

  location = var.artifact_registry_default_location

  repository_id = var.artifact_registry_repositories[count.index].name
  description   = var.artifact_registry_repositories[count.index].description
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "member" {
  project = var.gcp_project_id

  count = length(var.artifact_registry_repositories)

  location   = google_artifact_registry_repository.repositories[count.index].location
  repository = google_artifact_registry_repository.repositories[count.index].name

  role   = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.default.email}"
}

# GKE Cluster
resource "random_id" "main" {
  byte_length = 8 # TODO: Move to 4
}

resource "google_container_cluster" "main" {
  project  = var.gcp_project_id
  location = var.cluster_container_default_location

  name = "${var.cluster_container_name}-${random_id.main.hex}"

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.main.secondary_ip_range.0.range_name
    services_secondary_range_name = google_compute_subnetwork.main.secondary_ip_range.1.range_name
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  datapath_provider = "ADVANCED_DATAPATH"

  # cluster_autoscaling {
  #   autoscaling_profile = "OPTIMIZE_UTILIZATION"
  # }
  default_max_pods_per_node = 32

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = true
    }

    horizontal_pod_autoscaling {
      disabled = true
    }
  }
}

resource "google_container_node_pool" "system_nodes" {
  cluster = google_container_cluster.main.id

  name = "system-pool"

  node_count = 1

  max_pods_per_node = 32

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    disk_type = "pd-ssd"

    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/pubsub",
    ]
  }
}

resource "google_container_node_pool" "tools_nodes" {
  cluster = google_container_cluster.main.id

  name = "tools-pool"

  node_count = 1

  max_pods_per_node = 32

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    disk_type = "pd-ssd"

    taint {
      key    = "role"
      value  = "tools"
      effect = "NO_SCHEDULE"
    }

    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/pubsub",
    ]
  }
}

resource "google_container_node_pool" "publishers_nodes" {
  cluster = google_container_cluster.main.id

  name = "publishers-pool"

  node_count = 1

  max_pods_per_node = 32

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    disk_type = "pd-ssd"

    taint {
      key    = "role"
      value  = "publishers"
      effect = "NO_SCHEDULE"
    }

    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/logging.write",
    ]
  }
}

resource "google_container_node_pool" "subscribers_nodes" {
  cluster = google_container_cluster.main.id

  name = "subscribers-pool"

  node_count = 1

  max_pods_per_node = 32

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    disk_type = "pd-ssd"

    taint {
      key    = "role"
      value  = "subscribers"
      effect = "NO_SCHEDULE"
    }

    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/pubsub",
    ]
  }
}

// Create topics
resource "google_pubsub_topic" "node" {
  project = var.gcp_project_id

  name = "node-topic"
}

resource "google_pubsub_subscription" "node" {
  project = var.gcp_project_id

  name  = "node-subscription"
  topic = google_pubsub_topic.node.name
}

resource "google_pubsub_topic_iam_member" "publisher" {
  project = var.gcp_project_id

  topic = google_pubsub_topic.node.name

  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.default.email}"

  depends_on = [
    google_pubsub_topic.node,
  ]
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  project = var.gcp_project_id

  subscription = google_pubsub_subscription.node.name

  role   = "roles/pubsub.subscriber"
  member = "serviceAccount:${google_service_account.default.email}"

  depends_on = [
    google_pubsub_subscription.node,
  ]
}

resource "google_pubsub_subscription_iam_member" "viewer" {
  project = var.gcp_project_id

  subscription = google_pubsub_subscription.node.name

  role   = "roles/pubsub.viewer"
  member = "serviceAccount:${google_service_account.default.email}"

  depends_on = [
    google_pubsub_subscription.node,
  ]
}

resource "google_project_iam_member" "token_creator_binding" {
  project = var.gcp_project_id

  role   = "roles/iam.serviceAccountTokenCreator"
  member = "serviceAccount:${google_service_account.default.email}"
}
