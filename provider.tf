# The provider block tells Terraform which platform to talk to and how.
# Terraform itself is platform-agnostic; providers are plugins that
# translate the resource blocks you write into actual API calls.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
