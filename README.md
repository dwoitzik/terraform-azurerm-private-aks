# Azure Private AKS — Zero-Trust Edition

[![CI](https://github.com/dwoitzik/terraform-azurerm-private-aks/actions/workflows/tf-linter.yml/badge.svg)](https://github.com/dwoitzik/terraform-azurerm-private-aks/actions/workflows/tf-linter.yml)

> **Status: v0.1.0 — pre-1.0.** CI runs `terraform fmt`, `validate`, and `tflint` on every push, but this has never been through `terraform plan`/`apply` against a real Azure subscription. That proves syntax, not that it works. Reaching 1.0 needs a real plan-and-apply pass, which needs the operator (an Azure subscription, credentials, and someone watching the apply).

A private AKS cluster with no public API endpoint, no public node IPs, and no default outbound path — every packet a node sends leaves through a firewall you control, not through AKS's default Standard Load Balancer SNAT.

```
                         ┌─────────────────────┐
                         │   Azure Firewall     │  ← you supply the IP
                         │  (existing / NVA)     │
                         └──────────┬───────────┘
                                    │ UDR: 0.0.0.0/0
                         ┌──────────┴───────────┐
                         │   vnet-aks            │
                         │                       │
              ┌──────────┴──────────┐  ┌─────────┴──────────┐
              │  snet-aks-nodes     │  │ snet-private-       │
              │  (default-deny NSG) │  │ endpoints            │
              │                     │  │  - ACR (Premium)     │
              │  Private AKS        │  │  - Key Vault         │
              │  (no public FQDN)   │  │                      │
              └─────────────────────┘  └─────────────────────┘
```

This is the missing product between [azure-network-hub-spoke](https://github.com/dwoitzik/terraform-azurerm-hub-spoke) (the network) and [azure-firewall-forced-tunneling](https://github.com/dwoitzik/terraform-azurerm-firewall-forced-tunneling) (the egress control) — the actual workload cluster that sits behind both.

## 🚀 Features

- **No public API endpoint** — `private_cluster_enabled = true`, `private_cluster_public_fqdn_enabled = false`. Reach the control plane from inside the VNet, a peered network, or a VPN — never the internet.
- **Forced tunneling by default** — `outbound_type = "userDefinedRouting"` plus a Route Table sending `0.0.0.0/0` through your firewall's private IP. AKS cannot silently fall back to its own outbound path.
- **Zero-Trust node subnet NSG** — default-deny inbound, no exceptions baked in.
- **Private-endpoint-only ACR** — Premium SKU, `public_network_access_enabled = false`, `admin_enabled = false`. Nodes pull images via the kubelet's own managed identity (`AcrPull` role), never a shared credential.
- **Private-endpoint-only Key Vault** — RBAC-authorized, `public_network_access_enabled = false`. Kubelet identity gets `Key Vault Secrets User`, ready for the CSI Secrets Store driver.
- **Centralized Private DNS Zones** — `privatelink.<region>.azmk8s.io`, `privatelink.azurecr.io`, `privatelink.vaultcore.azure.net`, all with a DINE-policy-safe `lifecycle.ignore_changes` block so Terraform state doesn't fight Azure Policy remediation — same pattern as the hub-spoke module.
- **Azure CNI + Azure Network Policy** — real pod-to-pod NetworkPolicy enforcement, not the no-op kubenet default.

## 🛠️ Prerequisites

- Terraform `>= 1.5.0`
- Azure CLI (`az login`)
- An active Azure Subscription, Contributor rights on the target Resource Group
- **An existing firewall or NVA with a known private IP** — this module refuses to guess one for you. If you don't have one yet, deploy [azure-firewall-forced-tunneling](https://github.com/dwoitzik/terraform-azurerm-firewall-forced-tunneling) first.

## 📖 Usage

**1. Clone the repository**

```bash
git clone https://github.com/dwoitzik/terraform-azurerm-private-aks.git
cd terraform-azurerm-private-aks/terraform
```

**2. Configure your variables**

```bash
cp terraform.tfvars.example terraform.tfvars
```

At minimum, set `firewall_private_ip` to your firewall's actual private IP, and pick globally-unique `acr_name` / `key_vault_name` values.

**3. Deploy**

```bash
terraform init
terraform plan
terraform apply
```

**4. Connect to the private cluster**

The API server has no public FQDN. From a machine inside the VNet (or peered/VPN-connected to it):

```bash
az aks get-credentials --resource-group <rg_name> --name <aks_cluster_name>
kubectl get nodes
```

## 📁 Repository Structure

```
terraform/
├── main.tf                  # VNet, subnets, NSG, UDR, Private DNS, the AKS cluster
├── acr.tf                   # Private-endpoint-only Container Registry + AcrPull role
├── keyvault.tf               # Private-endpoint-only Key Vault (RBAC) + Secrets User role
├── variables.tf              # Input variable definitions
├── outputs.tf                 # Cluster ID, private FQDN, subnet/registry/vault IDs
├── terraform.tfvars.example  # Example configuration
└── .tflint.hcl                # azurerm ruleset config
```

## ⚠️ Known Limitations

This template deliberately keeps scope minimal:

- **You must already have a firewall.** This module does not deploy one — see [azure-firewall-forced-tunneling](https://github.com/dwoitzik/terraform-azurerm-firewall-forced-tunneling).
- **Single node pool.** No separate system/user node pool split, no spot node pools, no cluster autoscaler wiring. Extend `main.tf` for production multi-pool topologies.
- **No Azure AD / Entra RBAC integration wired up** — cluster auth is the AKS-managed local accounts path by default. Add `azure_active_directory_role_based_access_control` yourself if you need Entra-integrated `kubectl` auth.
- **`sku_tier` defaults to `Free`** — no uptime SLA. Set it to `Standard` for production.

---

## 📖 Deep Dive

The Shared Private Link approval deadlock, DNS trust-path design, and why `outbound_type = "userDefinedRouting"` is non-negotiable for a genuinely zero-trust cluster — covered in the companion writeup:

**[Zero-Trust RAG: Defeating the Shared Private Link Deadlock in Azure Terraform](https://woitzik.dev)**

Regulated environments (ISO 27001, NIS2, KRITIS) need proof that a workload cluster can't reach the internet except through an inspected path, and that the control plane isn't sitting on a public IP anyone can port-scan. Both are the actual default here, not a hardening step you have to remember to apply later.

---

## 📄 License

MIT — free to use, modify, and distribute.

*Built by [David Woitzik](https://woitzik.dev) · [LinkedIn](https://linkedin.com/in/david-woitzik)*
