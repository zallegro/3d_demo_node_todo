# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }
  required_version = ">= 0.14.9"
  #The Terraform state file will be stored remotely in my Azure storage account.
  #With remote state, Terraform writes the state data to a remote data store, 
  #which can then be shared between all members of a team. Remote state is implemented by a backend
  backend "azurerm" {
    storage_account_name = "__terraformstorageaccount__"
    container_name       = "terraform"
    key                  = "terraform.tfstate"
    access_key           = "__storagekey__"
    features{
    }
  }
}

provider "azurerm" {
  features {
  }
}

# Create the resource group
resource "azurerm_resource_group" "dev" {
  name     = "node-todo-demo3"
  location = "eastus"
}

# Create the Linux App Service Plan
# The app service plan defines the compute resources for the web application to run on.
# Some values in this configuration file have the prefix and suffix ‘__’. These are placeholder values.
resource "azurerm_app_service_plan" "dev" {
  name                = "__appserviceplan__"
  location            = "${azurerm_resource_group.dev.location}"
  resource_group_name = "${azurerm_resource_group.dev.name}"
  kind                = "Linux"
  reserved            = true # Must be true for Linux plans

  sku {
    tier = "Free"
    size = "F1"
  }
}

# Create the mongodb, pass in the App Service Plan ID
resource "azurerm_cosmosdb_account" "dev" {
  name                = "__appservicedb__"
  location            = "${azurerm_resource_group.dev.location}"
  resource_group_name = "${azurerm_resource_group.dev.name}"
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_automatic_failover = true
  mongo_server_version= "4.0"

  capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level  = "Eventual"
  }

  geo_location {
    location          = "${azurerm_resource_group.dev.location}"
    failover_priority = 0
  }
}

# Create the web app, pass in the App Service Plan ID
resource "azurerm_app_service" "dev" {
  name                = "__appservicename__"
  location            = "${azurerm_resource_group.dev.location}"
  resource_group_name = "${azurerm_resource_group.dev.name}"
  app_service_plan_id = "${azurerm_app_service_plan.dev.id}"

  site_config {
    # Free tier only supports 32-bit
    use_32_bit_worker_process = true
    # Run "az webapp list-runtimes --linux" for current supported values, but
    # always connect to the runtime with "az webapp ssh" or output the value
    # of process.version from a running app because you might not get the
    # version you expect
    linux_fx_version = "NODE|10-lts"
  }

  app_settings = {
    
    MONGO_URL = azurerm_cosmosdb_account.dev.connection_strings[0]
  }

  depends_on = [azurerm_cosmosdb_account.dev]


}