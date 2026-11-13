# ─── Object Storage Namespace ────────────────────────────────────────────────

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# ─── Object Storage Bucket (dsm-reports) ─────────────────────────────────────

resource "oci_objectstorage_bucket" "dsm_reports" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "dsm-reports"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"
}

# ─── Object Storage Bucket (bucket-shared) ───────────────────────────────────

resource "oci_objectstorage_bucket" "bucket_shared" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "bucket-shared"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"
}

# ─── Customer Secret Key (S3-Compatible Credentials) ─────────────────────────

resource "oci_identity_customer_secret_key" "s3_credentials" {
  user_id      = var.user_ocid
  display_name = "app-s3-key"
}
