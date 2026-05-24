terraform {
  required_version = ">= 1.9.0"
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = "2.2.1"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.14.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3"
    }
  }
}
