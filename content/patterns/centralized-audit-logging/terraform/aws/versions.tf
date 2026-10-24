terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

# Cuenta de log archive: acá viven el bucket y la clave KMS.
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# Cuenta de management (o administrador delegado): el trail de organización se crea desde ahí.
provider "aws" {
  alias  = "management"
  region = var.region

  default_tags {
    tags = var.tags
  }

  dynamic "assume_role" {
    for_each = var.management_role_arn == null ? [] : [var.management_role_arn]

    content {
      role_arn = assume_role.value
    }
  }
}
