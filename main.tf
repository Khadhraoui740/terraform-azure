locals {
  name_suffix = var.environment == "dev" ? "-dev" : ""

  resource_group_name           = "${var.resource_group_name}${local.name_suffix}"
  snowflake_resource_group_name = "${var.snowflake_resource_group_name}${local.name_suffix}"
  fabric_resource_group_name    = "${var.fabric_resource_group_name}${local.name_suffix}"
  # Fabric capacity names are globally unique across all of Azure (like
  # storage accounts), only allow lowercase letters/digits, and this
  # subscription already had "fabriccapacitydev" taken by someone else, so
  # derive a suffix from the subscription ID instead of guessing a free name.
  fabric_capacity_unique_suffix = substr(sha1(var.subscription_id), 0, 6)
  fabric_capacity_name          = "fabriccapacity${local.fabric_capacity_unique_suffix}${var.environment == "dev" ? "dev" : ""}"
  databricks_workspace_name     = "${var.databricks_workspace_name}${local.name_suffix}"
  unity_catalog_metastore_name  = "${var.unity_catalog_metastore_name}${local.name_suffix}"
  # Storage account names allow only lowercase letters/digits, so append a
  # plain "dev" instead of the hyphenated suffix used elsewhere.
  storage_account_name               = var.environment == "dev" ? "${var.storage_account_name}dev" : var.storage_account_name
  unity_catalog_storage_account_name = var.environment == "dev" ? "${var.unity_catalog_storage_account_name}dev" : var.unity_catalog_storage_account_name

  snowflake_stage_container_name    = "snowflake-stage${local.name_suffix}"
  snowflake_notification_queue_name = "snowflake-notifications${local.name_suffix}"
  snowflake_eventgrid_topic_name    = "snowflake-notifications${local.name_suffix}"
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
}

# --- Snowflake ---

resource "azurerm_resource_group" "snowflake" {
  name     = local.snowflake_resource_group_name
  location = var.location
}

# Dedicated container in the shared data lake for data Snowflake reads via
# an external stage (storage integration). Access is granted to Snowflake's
# own AAD app after the storage integration is created on the Snowflake side
# (DESC INTEGRATION gives the consent URL / app to grant Storage Blob Data
# Reader on this container) — that grant isn't in Terraform since it depends
# on values that only exist once the Snowflake-side object is created.
resource "azurerm_storage_container" "snowflake_stage" {
  name                  = local.snowflake_stage_container_name
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

# Queue that Snowpipe's notification integration listens on for new-blob
# events, so ingestion is auto-triggered instead of polled.
resource "azurerm_storage_queue" "snowflake_notifications" {
  name                 = local.snowflake_notification_queue_name
  storage_account_name = azurerm_storage_account.datalake.name
}

resource "azurerm_eventgrid_system_topic" "snowflake" {
  name = local.snowflake_eventgrid_topic_name
  # Azure requires a system topic's resource group to match its source
  # resource's, so this has to live with the storage account (azurerm_resource_group.this),
  # not in snowflakeRG.
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  source_arm_resource_id = azurerm_storage_account.datalake.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
}

# Routes BlobCreated events under the snowflake-stage container to the
# notification queue above. Same access-grant caveat as the container:
# Snowflake's notification integration principal needs Storage Queue Data
# Contributor on this queue, granted once the integration exists.
resource "azurerm_eventgrid_system_topic_event_subscription" "snowflake_notifications" {
  name                = "snowflake-blob-created"
  system_topic        = azurerm_eventgrid_system_topic.snowflake.name
  resource_group_name = azurerm_resource_group.this.name

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${azurerm_storage_container.snowflake_stage.name}/"
  }

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.datalake.id
    queue_name         = azurerm_storage_queue.snowflake_notifications.name
  }
}

# --- Microsoft Fabric ---

resource "azurerm_resource_group" "fabric" {
  name     = local.fabric_resource_group_name
  location = var.location
}

# No azurerm resource for Fabric Capacity exists on the azurerm 3.x provider
# line this config is pinned to (it needs 4.80+, a breaking major upgrade),
# so it's created via azapi instead against the ARM API directly.
resource "azapi_resource" "fabric_capacity" {
  type      = "Microsoft.Fabric/capacities@2023-11-01"
  name      = local.fabric_capacity_name
  parent_id = azurerm_resource_group.fabric.id
  location  = var.location

  body = {
    properties = {
      administration = {
        members = var.fabric_capacity_admin_members
      }
    }
    sku = {
      name = var.fabric_capacity_sku
      tier = "Fabric"
    }
  }
}

resource "azurerm_storage_account" "datalake" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                  = "TLS1_0"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
}

resource "azurerm_databricks_workspace" "this" {
  name                = local.databricks_workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.databricks_sku
}

# --- Unity Catalog ---

resource "azurerm_databricks_access_connector" "unity_catalog" {
  name                = "${local.databricks_workspace_name}-uc-connector"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }
}

# Dedicated ADLS Gen2 account for the metastore root storage (hierarchical
# namespace is required by Unity Catalog and can't be enabled retroactively
# on the existing "datalake" storage account without recreating it).
resource "azurerm_storage_account" "unity_catalog" {
  name                     = local.unity_catalog_storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
}

resource "azurerm_storage_container" "unity_catalog" {
  name                  = "metastore"
  storage_account_name  = azurerm_storage_account.unity_catalog.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "unity_catalog_storage" {
  scope                = azurerm_storage_account.unity_catalog.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

resource "databricks_metastore" "this" {
  count = var.enable_unity_catalog ? 1 : 0

  provider      = databricks.accounts
  name          = local.unity_catalog_metastore_name
  storage_root  = "abfss://${azurerm_storage_container.unity_catalog.name}@${azurerm_storage_account.unity_catalog.name}.dfs.core.windows.net/"
  region        = azurerm_resource_group.this.location
  force_destroy = true
}

resource "databricks_metastore_data_access" "this" {
  count = var.enable_unity_catalog ? 1 : 0

  provider     = databricks.accounts
  metastore_id = databricks_metastore.this[0].id
  name         = azurerm_databricks_access_connector.unity_catalog.name
  is_default   = true

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity_catalog.id
  }
}

resource "databricks_metastore_assignment" "this" {
  count = var.enable_unity_catalog ? 1 : 0

  provider     = databricks.accounts
  metastore_id = databricks_metastore.this[0].id
  workspace_id = azurerm_databricks_workspace.this.workspace_id

  depends_on = [databricks_metastore_data_access.this]
}
