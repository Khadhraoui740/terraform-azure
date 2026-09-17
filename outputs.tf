output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "storage_account_id" {
  value = azurerm_storage_account.datalake.id
}

output "storage_account_primary_blob_endpoint" {
  value = azurerm_storage_account.datalake.primary_blob_endpoint
}

output "databricks_workspace_id" {
  value = azurerm_databricks_workspace.this.id
}

output "databricks_workspace_url" {
  value = azurerm_databricks_workspace.this.workspace_url
}

output "databricks_access_connector_id" {
  value = azurerm_databricks_access_connector.unity_catalog.id
}

output "unity_catalog_storage_account_id" {
  value = azurerm_storage_account.unity_catalog.id
}

output "unity_catalog_metastore_id" {
  value = var.enable_unity_catalog ? databricks_metastore.this[0].id : null
}

output "snowflake_storage_account_name" {
  value = azurerm_storage_account.snowflake.name
}

output "snowflake_stage_container_name" {
  value = azurerm_storage_container.snowflake_stage.name
}

output "snowflake_notification_queue_name" {
  value = azurerm_storage_queue.snowflake_notifications.name
}

output "snowflake_notification_queue_id" {
  value = azurerm_storage_queue.snowflake_notifications.id
}

output "azure_tenant_id" {
  value = var.tenant_id
}
