# ─── Outputs ─────────────────────────────────────────────────────────────────

output "instance_private_ip" {
  description = "Private IP of the Ubuntu VM"
  value       = oci_core_instance.vm_app.create_vnic_details[0].private_ip
}

output "instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.vm_app.id
}

output "nat_gateway_ip" {
  description = "Public Egress IP of the OCI NAT Gateway"
  value       = oci_core_nat_gateway.nat_gateway.nat_ip
}

output "bastion_id" {
  description = "OCID of the OCI Bastion service"
  value       = oci_bastion_bastion.bastion.id
}

output "object_storage_bucket" {
  description = "Name of the S3-compatible reports bucket"
  value       = oci_objectstorage_bucket.dsm_reports.name
}

output "object_storage_endpoint" {
  description = "S3-compatible endpoint for Object Storage"
  value       = "https://${data.oci_objectstorage_namespace.ns.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "approved_sender" {
  description = "Registered sender in OCI Email Delivery"
  value       = oci_email_sender.approved_sender.email_address
}

output "admin_sender" {
  description = "Secondary registered sender in OCI Email Delivery"
  value       = oci_email_sender.admin_sender.email_address
}

output "shared_bucket" {
  description = "Name of the shared Object Storage bucket"
  value       = oci_objectstorage_bucket.bucket_shared.name
}
