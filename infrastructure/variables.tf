// Project
//

variable "gcp_organization_id" {
  type = string
}

variable "gcp_billing_account_id" {
  type = string
}

variable "gcp_project_id" {
  type    = string
  default = "pubsub-benchmark"
}

variable "gcp_project_name" {
  type    = string
  default = "PubSub Benchmark"
}

variable "gcp_project_enforce_policies" {
  type = list(object({
    constraint = string
    enforce    = bool
  }))
  default = [
    # { constraint = "compute.requireOsLogin", enforce = false },
    # { constraint = "compute.requireShieldedVm", enforce = false },
    # { constraint = "constraints/iam.disableServiceAccountKeyCreation", enforce = false },
  ]
}

variable "gcp_project_allow_policies" {
  type = list(object({
    constraint = string
    allow      = bool
  }))
  default = [
    # { constraint = "compute.restrictVpcPeering", allow = true },
    # { constraint = "compute.vmCanIpForward", allow = true },
    # { constraint = "compute.vmExternalIpAccess", allow = true },
  ]
}

// Services
//

variable "gcp_project_services" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
  ]
}

// Network
//
variable "vpc_name" {
  type    = string
  default = "default"
}

variable "vpc_region" {
  type    = string
  default = "europe-west9"
}

variable "vpc_subnetwork_name" {
  type    = string
  default = "default"
}

variable "vpc_subnetwork_ip_cidr_range" {
  type    = string
  default = "10.0.0.0/16" # ±65K
}

variable "vpc_subnetwork_secondary_ip_ranges" {
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = [
    {
      range_name    = "services-range"
      ip_cidr_range = "10.1.0.0/22" # ±1.0K
    },
    {
      range_name    = "pod-ranges-primary"
      ip_cidr_range = "10.2.0.0/16" # ±65K
    }
  ]
}

// Artifact registry repositories
//

variable "artifact_registry_default_location" {
  type    = string
  default = "europe-west9"
}

variable "artifact_registry_repositories" {
  type = list(object({
    name        = string
    description = string
  }))
  default = [
    { name = "locust", description = "Scalable performance testing tool." },
    { name = "pubsub-node", description = "PubSub emitter/reciever NodeJS" },
  ]
}

// GKE Cluster
//

variable "name" {
  type    = string
  default = "default"
}

variable "cluster_container_default_location" {
  type    = string
  default = "europe-west9"
}

variable "cluster_container_name" {
  type    = string
  default = "main"
}
