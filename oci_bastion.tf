# ─── OCI Bastion Service (Zero-Cost Managed Bastion) ─────────────────────────

resource "oci_bastion_bastion" "bastion" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  target_subnet_id = oci_core_subnet.private_subnet.id
  name             = "bastionShared"

  client_cidr_block_allow_list = ["0.0.0.0/0"]
  max_session_ttl_in_seconds   = 10800 # 3 hours
}
