output "aks_cluster_id" {
  description = "The ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "aks_private_fqdn" {
  description = "The private FQDN of the AKS API server. Only resolvable from inside the VNet (or a peered/connected network)."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "vnet_id" {
  description = "The ID of the AKS Virtual Network."
  value       = azurerm_virtual_network.aks.id
}

output "aks_subnet_id" {
  description = "The ID of the AKS node subnet."
  value       = azurerm_subnet.aks_nodes.id
}

output "private_endpoint_subnet_id" {
  description = "The ID of the subnet used for Private Endpoints (ACR, Key Vault)."
  value       = azurerm_subnet.private_endpoints.id
}

output "acr_id" {
  description = "The ID of the Container Registry, if deployed."
  value       = var.deploy_acr ? azurerm_container_registry.this[0].id : null
}

output "key_vault_id" {
  description = "The ID of the Key Vault, if deployed."
  value       = var.deploy_key_vault ? azurerm_key_vault.this[0].id : null
}
