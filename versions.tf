terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.71.0"
    }
  }
}

provider "azurerm" {
  features {
      app_configuration {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = true
    }
    resource_group {
    prevent_deletion_if_contains_resources = false #Added in for people using this for training - switch to true if you plan on using this for other things
    }
  }
}