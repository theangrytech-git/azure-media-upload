/*******************************************************************************

PROJECT NAME:       AZURE-MEDIA-UPLOAD
CREATED BY:         THEANGRYTECH-GIT
REPO:               https://github.com/theangrytech-git/azure-media-upload
DESCRIPTION:        This project sets up an Azure environment where users can 
                    upload videos and pictures through a website portal, store 
                    them, and categorize them. It includes separate portals 
                    for images and videos, routing traffic accordingly, and 
                    storing media files in Azure Storage with metadata managed 
                    in Azure SQL Database.

*******************************************************************************/


/*******************************************************************************
                         CREATE RESOURCE GROUPS
*******************************************************************************/

resource "azurerm_resource_group" "web" {
  name     = "rg-uks-web"
  location = "uksouth"
}

resource "azurerm_resource_group" "storage" {
  name     = "rg-uks-storage"
  location = "uksouth"
}

resource "azurerm_resource_group" "networking" {
  name     = "rg-uks-networking"
  location = "uksouth"
}

resource "azurerm_resource_group" "database" {
  name     = "rg-uks-database"
  location = "uksouth"
}

/*******************************************************************************
                         CREATE VIRTUAL NETWORKS
*******************************************************************************/

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-uks-main"
  address_space       = ["10.0.0.0/19"]
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
}

resource "azurerm_subnet" "web" {
  name                 = "snet-uks-web"
  resource_group_name  = azurerm_resource_group.web.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/28"]
}

resource "azurerm_subnet" "storage" {
  name                 = "snet-uks-storage"
  resource_group_name  = azurerm_resource_group.storage.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/28"]
}

resource "azurerm_subnet" "database" {
  name                 = "snet-uks-db"
  resource_group_name  = azurerm_resource_group.database.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/28"]
}

resource "azurerm_subnet" "networking" {
  name                 = "snet-uks-network"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/28"]
}

/*******************************************************************************
                         CREATE APP SERVICE PLAN
*******************************************************************************/

resource "azurerm_service_plan" "web_asp" {
  name                = "asp-uks-web-01"
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  os_type = "windows"
  sku_name = "S1"
}

/*******************************************************************************
                         CREATE APP SERVICES
*******************************************************************************/

resource "azurerm_windows_web_app" "main" {
  name                = "app-web-main"
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  service_plan_id     = azurerm_service_plan.web_asp.id

  site_config {}
}

resource "azurerm_windows_web_app" "image" {
  name                = "app-web-image"
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  service_plan_id     = azurerm_service_plan.web_asp.id
  app_settings = {
  "AZURE_STORAGE_ACCOUNT_NAME" = azurerm_storage_account.image_storage.name
  "AZURE_STORAGE_ACCOUNT_KEY"  = azurerm_storage_account.image_storage.primary_access_key
  "DATABASE_URL"               = "Server=${azurerm_sql_server.sql_server.fqdn};Database=${azurerm_sql_database.image_db.name};User Id=${azurerm_sql_server.sql_server.administrator_login};Password=${azurerm_sql_server.sql_server.administrator_login_password};"
  "APPINSIGHTS_INSTRUMENTATIONKEY"   = azurerm_application_insights.app_insights.instrumentation_key
  "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
  }
  site_config {}  
}


resource "azurerm_windows_web_app" "video" {
  name                = "app-web-video"
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  service_plan_id     = azurerm_service_plan.web_asp.id
  app_settings = {
    "AZURE_STORAGE_ACCOUNT_NAME" = azurerm_storage_account.video_storage.name
    "AZURE_STORAGE_ACCOUNT_KEY"  = azurerm_storage_account.video_storage.primary_access_key
    "DATABASE_URL"               = "Server=${azurerm_sql_server.sql_server.fqdn};Database=${azurerm_sql_database.video_db.name};User Id=${azurerm_sql_server.sql_server.administrator_login};Password=${azurerm_sql_server.sql_server.administrator_login_password};"
    "APPINSIGHTS_INSTRUMENTATIONKEY"   = azurerm_application_insights.app_insights.instrumentation_key
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
  }
  site_config {}
}

/*******************************************************************************
                         CREATE STORAGE
*******************************************************************************/

resource "azurerm_storage_account" "storage" {
  name                     = "sa-uks-webapp"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}
resource "azurerm_storage_container" "image_container" {
  name                  = "container-uks-imagefiles"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "video_container" {
  name                  = "container-uks-videofiles"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

/*******************************************************************************
                         CREATE DATABASE
                 (FOR METADATA AND CATEGORISATION)
*******************************************************************************/

resource "aazurerm_mssql_server" "sql_server" {
  name                         = "sql-uks-media"
  resource_group_name          = azurerm_resource_group.database.name
  location                     = azurerm_resource_group.database.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "Password1234!" #Obsure and randomise. Hardcoded for testing right now.
  minimum_tls_version          = "1.2"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_database" "image_db" {
  name                = "db-uks-image"
  server_id         = azurerm_sql_server.sql_server.name
  max_size_gb    = 50
  read_scale     = true
  sku_name       = "S0"
  zone_redundant = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_database" "video_db" {
  name                = "db-uks-video"
  server_id         = azurerm_sql_server.sql_server.name
  max_size_gb    = 50
  read_scale     = true
  sku_name       = "S0"
  zone_redundant = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "image_db_diagnostics" {
  name               = "diagnostics-image"
  target_resource_id = azurerm_sql_database.image_db.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "Errors"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "video_db_diagnostics" {
  name               = "diagnostics-video"
  target_resource_id = azurerm_sql_database.video_db.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "Errors"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

/*******************************************************************************
                         CREATE TRAFFIC MANAGER
*******************************************************************************/

resource "azurerm_traffic_manager_profile" "traffic_manager" {
  name                = "tm-global-media"
  resource_group_name = azurerm_resource_group.networking.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "media"
    ttl           = 30
  }

  monitor_config {
    protocol = "HTTP"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "main_endpoint" {
  name                = "tm-global-main-endpoint"
  resource_group_name = azurerm_resource_group.web.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  type                = "azureEndpoints"
  target_resource_id  = azurerm_windows_web_app.main.id
  priority            = 1
}

resource "azurerm_traffic_manager_endpoint" "video_endpoint" {
  name                = "tm-global-video-endpoint"
  resource_group_name = azurerm_resource_group.web.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  type                = "azureEndpoints"
  target_resource_id  = azurerm_windows_web_app.video.id
  priority            = 2
}

resource "azurerm_traffic_manager_endpoint" "image_endpoint" {
  name                = "tm-global-image-endpoint"
  resource_group_name = azurerm_resource_group.web.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  type                = "azureEndpoints"
  target_resource_id  = azurerm_windows_web_app.image.id
  priority            = 3
}

/*******************************************************************************
                         CREATE APPLICATION INSIGHTS
*******************************************************************************/

resource "azurerm_application_insights" "app_insights" {
  name                = "appin-uks-media-01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

/*******************************************************************************
                         CREATE LOG ANALYTIC WORKSPACE
*******************************************************************************/

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-uks-sql-01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
}