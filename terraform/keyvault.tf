# ==========================================
# Key Vault — no public endpoint, RBAC authorization
# ==========================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  count                         = var.deploy_key_vault ? 1 : 0
  name                          = var.key_vault_name
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_private_dns_zone" "kv" {
  count               = var.deploy_key_vault ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  count                 = var.deploy_key_vault ? 1 : 0
  name                  = "link-kv-${var.environment}"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv[0].name
  virtual_network_id    = azurerm_virtual_network.aks.id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  count               = var.deploy_key_vault ? 1 : 0
  name                = "pe-${var.key_vault_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.this[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv[0].id]
  }
}

# Cluster's kubelet identity gets read access via CSI Secrets Store driver pattern —
# grant the role, wiring up the SecretProviderClass is left to the consuming workload.
resource "azurerm_role_assignment" "aks_kv_secrets_user" {
  count                = var.deploy_key_vault ? 1 : 0
  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
