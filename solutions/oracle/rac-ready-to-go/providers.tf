########################################################
# Terraform Providers Configuration
########################################################

terraform {
  required_version = ">= 1.9"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">=1.80.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}

########################################################
# IBM Cloud Provider - VPC (Intel VSI)
########################################################
provider "ibm" {
  alias            = "ibm-is"
  region           = local.vpc_region
  zone             = local.vpc_zone
  ibmcloud_api_key = var.ibmcloud_api_key != null ? var.ibmcloud_api_key : null
}

########################################################
# IBM Cloud Provider - PowerVS
########################################################
provider "ibm" {
  alias            = "ibm-pi"
  region           = local.powervs_region
  zone             = var.powervs_zone
  ibmcloud_api_key = var.ibmcloud_api_key != null ? var.ibmcloud_api_key : null
}

########################################################
# IBM Cloud Provider - Secrets Manager
########################################################
provider "ibm" {
  alias            = "ibm-sm"
  region           = local.vpc_region
  ibmcloud_api_key = var.ibmcloud_api_key != null ? var.ibmcloud_api_key : null
}