# Oracle Cloud Infrastructure (OCI) - Terraform IaC

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4.svg?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Cloud Provider](https://img.shields.io/badge/Cloud-Oracle_Cloud_(Always_Free)-F80000.svg?logo=oracle&logoColor=white)](https://cloud.oracle.com/)
[![Security](https://img.shields.io/badge/Architecture-Zero_Public_IP-success.svg)](#security-best-practices)

This repository contains the complete **Terraform Infrastructure as Code (IaC)** configuration for the cloud infrastructure running on **Oracle Cloud Infrastructure (OCI Always Free)** with zero public IP exposure and outbound-only connectivity.

---

## 🏗️ Architecture Topology

```
                              PUBLIC INTERNET
                                     │
                    ┌────────────────▼────────────────┐
                    │      Cloudflare Edge Network    │
                    │   (SSL/TLS, DDoS Shield, WAF)   │
                    └────────────────┬────────────────┘
                                     │ Encrypted Outbound Tunnel (cloudflared)
                                     ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  ORACLE CLOUD INFRASTRUCTURE (VCN: 10.0.0.0/16, Region: us-phoenix-1)        │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  OCI NAT Gateway - Outbound Internet Access for Private VM           │   │
│   └──────────────────────────────────┬───────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼───────────────────────────────────┐   │
│   │  PRIVATE SUBNET (10.0.0.0/24) - Zero Public IP Assigned              │   │
│   │                                                                      │   │
│   │   ┌──────────────────────────────────────────────────────────────┐   │   │
│   │   │  Compute Instance: `vm-alwaysfree-shared` (10.0.0.135)       │   │   │
│   │   │  - Shape: Ampere A1 Flex (2 OCPU, 6 GB RAM, ARM64)           │   │   │
│   │   │  - OS: Ubuntu 24.04 LTS (aarch64)                            │   │   │
│   │   │  - Services:                                                 │   │   │
│   │   │      • Web Application / Nginx                               │   │   │
│   │   │      • cloudflared (Zero Trust Ingress Daemon)               │   │   │
│   │   │      • GitHub Actions Self-Hosted Runner                     │   │   │
│   │   └──────────────────────────────────────────────────────────────┘   │   │
│   │                                                                      │   │
│   │   ┌──────────────────────────────────────────────────────────────┐   │   │
│   │   │  OCI Bastion Service: `bastionShared`                        │   │   │
│   │   │  - Managed Zero-Cost Ephemeral SSH Port-Forwarding           │   │   │
│   │   └──────────────────────────────────────────────────────────────┘   │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  OCI Object Storage: `dsm-reports` (Standard Tier) + S3 Keys         │   │
│   │  - Compatible with AWS S3 SDKs / tools                               │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  OCI Email Delivery (SMTP :587)                                      │   │
│   │  - Approved Sender & SMTP Credentials                                │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

| File | Description |
|---|---|
| [`versions.tf`](./versions.tf) | Minimum Terraform version (`>= 1.5.0`) & provider declarations for `oracle/oci` and `hashicorp/random`. |
| [`variables.tf`](./variables.tf) | Input variables with descriptions, types, and defaults matching target resources. |
| [`terraform.tfvars.example`](./terraform.tfvars.example) | Example input values for variables (copy to `terraform.tfvars`). |
| [`oci_network.tf`](./oci_network.tf) | VCN (`10.0.0.0/16`), Private Subnet (`10.0.0.0/24`), NAT & Internet Gateways, Route Table, Security List, and VM Network Security Group (`ig-quick-action-NSG`). |
| [`oci_compute.tf`](./oci_compute.tf) | Ampere A1 Flex VM (`vm-alwaysfree-shared`), VNIC (Private IP `10.0.0.135`), OS Image. |
| [`oci_bastion.tf`](./oci_bastion.tf) | Managed OCI Bastion service (`bastionShared`) for secure private SSH access. |
| [`oci_storage.tf`](./oci_storage.tf) | Object Storage buckets (`dsm-reports`, `bucket-shared`) & S3-compatible Customer Secret Key. |
| [`oci_email.tf`](./oci_email.tf) | OCI Email Delivery Approved Senders & SMTP Credentials. |
| [`outputs.tf`](./outputs.tf) | Exports private IP, instance ID, NAT IP, Bastion OCID, bucket names, Object Storage endpoint, and approved senders. |
| [`SECURITY_HARDENING.md`](./SECURITY_HARDENING.md) | In-depth security guide for NAT Gateway, Cloudflare Tunnel, Fail2ban, and SSH. |

---

## 🚀 Getting Started

### 1. Prerequisites
* [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
* OCI API Signing Key configured in `~/.oci/config` (or SecurityToken authentication)
* Valid OCI Tenancy and User OCIDs

---

### 2. Configure Variables

```bash
# Clone the repository
git clone https://github.com/ruchira05/oci-always-free-terraform.git
cd oci-always-free-terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific OCI details:
```hcl
tenancy_ocid        = "ocid1.tenancy.oc1..aaaaaaa..."
compartment_ocid    = "ocid1.tenancy.oc1..aaaaaaa..."
user_ocid           = "ocid1.user.oc1..aaaaaaa..."
region              = "us-phoenix-1"
availability_domain = "jhfc:PHX-AD-1"
fingerprint         = "<YOUR_FINGERPRINT>"
private_key_path    = "~/.oci/oci_api_key.pem"
```

---

### 3. Initialize & Deploy

```bash
# 1. Initialize Terraform providers
terraform init

# 2. Preview changes
terraform plan

# 3. Apply infrastructure
terraform apply
```

---

### 4. Importing Existing Live Resources (Optional)

If the resources are already created in your OCI console and you want to import them into Terraform state:

```bash
# 1. Import VCN
terraform import oci_core_vcn.vcn_shared <VCN_OCID>

# 2. Import NAT Gateway
terraform import oci_core_nat_gateway.nat_gateway <NAT_GATEWAY_OCID>

# 3. Import Private Subnet
terraform import oci_core_subnet.private_subnet <SUBNET_OCID>

# 4. Import Compute Instance
terraform import oci_core_instance.vm_app <INSTANCE_OCID>

# 5. Import Bastion
terraform import oci_bastion_bastion.bastion <BASTION_OCID>

# 6. Import Object Storage Bucket
terraform import oci_objectstorage_bucket.dsm_reports n/<NAMESPACE>/b/dsm-reports

# 7. Import Approved Senders
terraform import oci_email_sender.approved_sender <APPROVED_SENDER_OCID>
terraform import oci_email_sender.admin_sender <ADMIN_SENDER_OCID>

# 8. Import remaining network resources
#    (The VCN default route table & security list need no import: they are
#     adopted automatically through manage_default_resource_id.)
terraform import oci_core_internet_gateway.internet_gateway <IGW_OCID>
terraform import oci_core_network_security_group.vm_nsg <NSG_OCID>
terraform import oci_core_network_security_group_security_rule.vm_nsg_egress_all networkSecurityGroups/<NSG_OCID>/securityRules/<RULE_ID>

# 9. Import second bucket
terraform import oci_objectstorage_bucket.bucket_shared n/<NAMESPACE>/b/bucket-shared
```

---

## 🔒 Security Best Practices

* **Zero Public IP:** The compute instance has no public IP assigned.
* **Strict Egress via NAT:** Outbound connections (updates, webhooks, cloudflared) flow through the NAT Gateway. Inbound traffic from the public internet is 100% blocked at the network perimeter.
* **Ephemeral Bastion Access:** Direct SSH port 22 is disabled on the public internet. Access is only possible through temporary, audited OCI Bastion sessions.
* **Cloudflare Tunnel Ingress:** Web traffic arrives strictly via encrypted outbound tunnel (`cloudflared`) without requiring any inbound open ports.

For detailed host hardening steps (UFW, Fail2ban, SSH hardening, and automated updates), consult [SECURITY_HARDENING.md](./SECURITY_HARDENING.md).

---

## 📄 License

Released under the [MIT License](./LICENSE).
