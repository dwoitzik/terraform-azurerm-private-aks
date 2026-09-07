# ==========================================
# Resource Group
# ==========================================

resource "azurerm_resource_group" "rg" {
  name     = "${var.rg_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ==========================================
# VNet + Subnets
# ==========================================

resource "azurerm_virtual_network" "aks" {
  name                = "vnet-aks-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_cidr
  tags                = var.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = var.aks_subnet_cidr
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = var.pe_subnet_cidr

  private_endpoint_network_policies_enabled = true
}

# ==========================================
# Zero-Trust NSG — default-deny inbound, node subnet only
# ==========================================

resource "azurerm_network_security_group" "aks_nodes" {
  name                = "nsg-aks-nodes-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks_nodes.id
}

# ==========================================
# Forced Tunneling — all node egress via Azure Firewall
# ==========================================

resource "azurerm_route_table" "aks_egress" {
  name                = "rt-aks-egress-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "aks_nodes" {
  subnet_id      = azurerm_subnet.aks_nodes.id
  route_table_id = azurerm_route_table.aks_egress.id
}

# ==========================================
# Private DNS Zone for the AKS API server
# ==========================================

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  # Azure Policy DINE assignments (Private DNS auto-remediation) commonly manage
  # these records out-of-band. Without this, every `terraform plan` shows drift
  # that isn't actually a problem — same DINE-policy pattern as the hub-spoke module.
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "link-aks-${var.environment}"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.aks.id
  tags                  = var.tags
}

# ==========================================
# Private AKS Cluster
# ==========================================

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.aks_cluster_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.aks_cluster_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  # No public API endpoint. Reach the control plane via VNet peering, VPN,
  # or a jumpbox inside this VNet — never over the internet.
  private_cluster_enabled             = true
  private_dns_zone_id                 = azurerm_private_dns_zone.aks.id
  private_cluster_public_fqdn_enabled = false

  # Nodes have no public IPs and no default outbound (Standard LB SNAT) path —
  # every packet leaving a node is forced through the firewall via the UDR above.
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "userDefinedRouting"
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    node_count                  = var.node_count
    vnet_subnet_id              = azurerm_subnet.aks_nodes.id
    temporary_name_for_rotation = "systemtmp"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_subnet_route_table_association.aks_nodes,
    azurerm_private_dns_zone_virtual_network_link.aks,
  ]
}
