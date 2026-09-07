# ==========================================
# Container Registry — no public endpoint, Premium SKU (required for Private Link)
# ==========================================

resource "azurerm_container_registry" "this" {
  count                         = var.deploy_acr ? 1 : 0
  name                          = var.acr_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  count               = var.deploy_acr ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.deploy_acr ? 1 : 0
  name                  = "link-acr-${var.environment}"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = azurerm_virtual_network.aks.id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.deploy_acr ? 1 : 0
  name                = "pe-${var.acr_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.acr_name}"
    private_connection_resource_id = azurerm_container_registry.this[0].id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }
}

# Kubelet identity (the identity nodes actually pull images with) gets AcrPull —
# never admin_enabled credentials, never a shared pull secret.
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                            = var.deploy_acr ? 1 : 0
  scope                            = azurerm_container_registry.this[0].id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
