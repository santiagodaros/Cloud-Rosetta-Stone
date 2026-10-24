terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }
  }
}

# Sin project ni region: las policies de organización y de carpeta no pertenecen a un proyecto.
provider "google" {}
