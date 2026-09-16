variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "1530c703-85b0-412b-9f7d-e317edb13e6a"
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  default     = "e51ffb8d-9846-4f8e-8e2f-a05bfe018165"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "databriksRG"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
  default     = "pstdatalake001"
}

variable "databricks_workspace_name" {
  description = "Name of the Databricks workspace"
  type        = string
  default     = "databriks-workspace"
}

variable "databricks_sku" {
  description = "Pricing tier for the Databricks workspace (standard, premium or trial). Unity Catalog needs premium."
  type        = string
  default     = "premium"
}

variable "enable_unity_catalog" {
  description = "Whether to create the Unity Catalog metastore and assign it to the workspace. Leave false until the Databricks account exists and you have its account_id (the account is created automatically the first time a workspace is deployed in the tenant)."
  type        = bool
  default     = false
}

variable "databricks_account_id" {
  description = "Databricks account ID (from the Databricks account console), used to manage the Unity Catalog metastore. Required only when enable_unity_catalog = true."
  type        = string
  default     = ""
}

variable "databricks_client_id" {
  description = "Application (client) ID of the Azure AD service principal used to authenticate to the Databricks account console. Must be an account admin. Required only when enable_unity_catalog = true."
  type        = string
  default     = ""
}

variable "databricks_client_secret" {
  description = "Client secret of the Azure AD service principal used to authenticate to the Databricks account console. Required only when enable_unity_catalog = true."
  type        = string
  sensitive   = true
  default     = ""
}

variable "unity_catalog_storage_account_name" {
  description = "Name of the dedicated ADLS Gen2 (hierarchical namespace) storage account used as Unity Catalog metastore root storage"
  type        = string
  default     = "databriksucmetastore"
}

variable "unity_catalog_metastore_name" {
  description = "Name of the Unity Catalog metastore"
  type        = string
  default     = "databriks-uc-metastore"
}
