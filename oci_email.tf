# ─── OCI Email Delivery Approved Sender ──────────────────────────────────────

resource "oci_email_sender" "approved_sender" {
  compartment_id = var.compartment_ocid
  email_address  = var.approved_sender_email
}

resource "oci_email_sender" "admin_sender" {
  compartment_id = var.compartment_ocid
  email_address  = var.admin_sender_email
}

# ─── OCI SMTP Credential ─────────────────────────────────────────────────────

resource "oci_identity_smtp_credential" "smtp_credential" {
  user_id     = var.user_ocid
  description = "app-smtp"
}
