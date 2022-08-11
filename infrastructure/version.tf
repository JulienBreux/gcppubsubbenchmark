terraform {
  required_version = "= v1.2.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 4.31.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
  }
}
