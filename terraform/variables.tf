variable "location" {
  type        = string
  description = "Azure Region for the deployment"
  default     = "westeurope"
}

variable "rg_name" {
  type        = string
  description = "Name of the Resource Group"
  default     = "rg-aks-private-base"
}

variable "environment" {
  type        = string
  description = "The environment name (e.g., dev, test, prod)."
}

variable "tags" {
  type        = map(string)
  description = "Standard tags to apply to all resources."
  default     = {}
}

variable "vnet_cidr" {
  type        = list(string)
  description = "CIDR block for the AKS VNet."
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_cidr" {
  type        = list(string)
  description = "CIDR block for the AKS node subnet."
  default     = ["10.10.1.0/24"]
}

variable "pe_subnet_cidr" {
  type        = list(string)
  description = "CIDR block for the Private Endpoint subnet (ACR, Key Vault)."
  default     = ["10.10.2.0/24"]
}

variable "firewall_private_ip" {
  type        = string
  description = <<-EOT
    Private IP of an Azure Firewall (or NVA) to force-tunnel all node egress through
    via a User Defined Route. This module never puts the AKS API server or nodes on
    the public internet, so this is required, not optional — pair with
    github.com/dwoitzik/azure-firewall-forced-tunneling if you don't already have a
    firewall deployed.
  EOT
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the AKS cluster."
  default     = "aks-private-base"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version. Leave null to use the current AKS default."
  default     = null
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool."
  default     = 2
}

variable "node_vm_size" {
  type        = string
  description = "VM size for the default node pool."
  default     = "Standard_D2s_v5"
}

variable "sku_tier" {
  type        = string
  description = "AKS control plane SKU tier. 'Free' has no uptime SLA; use 'Standard' for production."
  default     = "Free"
}

variable "deploy_acr" {
  type        = bool
  description = "Whether to deploy a private-endpoint-only Container Registry wired to the cluster's kubelet identity."
  default     = true
}

variable "acr_name" {
  type        = string
  description = "Globally unique ACR name (5-50 alphanumeric characters, no hyphens). Only used if deploy_acr is true."
  default     = "acrprivatebase"
}

variable "deploy_key_vault" {
  type        = bool
  description = "Whether to deploy a private-endpoint-only Key Vault."
  default     = true
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name (3-24 alphanumeric/hyphen characters). Only used if deploy_key_vault is true."
  default     = "kv-aks-private-base"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID for Key Vault access policies. Only used if deploy_key_vault is true."
  default     = null
}
