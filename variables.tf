# ─── Oracle Cloud Infrastructure (OCI) Variables ─────────────────────────────

variable "tenancy_ocid" {
  type        = string
  description = "The OCID of the Oracle Cloud tenancy"
}

variable "compartment_ocid" {
  type        = string
  description = "The OCID of the compartment where resources reside"
}

variable "user_ocid" {
  type        = string
  description = "The OCID of the OCI user managing the infrastructure"
}

variable "fingerprint" {
  type        = string
  description = "The fingerprint of the API key used for authentication"
  default     = ""
}

variable "private_key_path" {
  type        = string
  description = "Path to the OCI API private key file"
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_config_profile" {
  type        = string
  description = "Profile in ~/.oci/config used for SecurityToken auth (created by `oci session authenticate`)"
  default     = "DEFAULT"
}

variable "region" {
  type        = string
  description = "OCI region"
  default     = "us-phoenix-1"
}

variable "availability_domain" {
  type        = string
  description = "OCI Availability Domain"
  default     = "jhfc:PHX-AD-1"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for the Ubuntu VM"
}

variable "instance_shape" {
  type        = string
  description = "Compute instance shape (Ampere A1 Always Free)"
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  type        = number
  description = "Number of OCPUs allocated to the instance"
  default     = 2
}

variable "instance_memory_in_gbs" {
  type        = number
  description = "Memory in GBs allocated to the instance"
  default     = 6
}

variable "image_ocid" {
  type        = string
  description = "OCID of the OS image (Ubuntu 24.04 aarch64)"
  default     = "ocid1.image.oc1.phx.aaaaaaaafyvgnzeatevnnrx2yuay2p7uarefgnbhibpwwk2gkor4r5zbumea"
}

variable "approved_sender_email" {
  type        = string
  description = "Approved email sender address for OCI Email Delivery"
}

variable "admin_sender_email" {
  type        = string
  description = "Secondary approved email sender address for OCI Email Delivery (set in terraform.tfvars)"
}

# ─── Cloudflare Variables ───────────────────────────────────────────────────

variable "cloudflare_account_id" {
  type        = string
  description = "The Cloudflare Account ID"
  default     = ""
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token with Zero Trust and DNS permissions"
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for example.com"
  default     = ""
}

variable "domain" {
  type        = string
  description = "Apex domain name"
  default     = "example.com"
}

variable "subdomain" {
  type        = string
  description = "Subdomain for App application"
  default     = "app"
}
