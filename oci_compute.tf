# ─── Compute Instance (Ampere A1 Flex - Always Free) ─────────────────────────

resource "oci_core_instance" "vm_app" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "vm-alwaysfree-shared"
  shape               = var.instance_shape
  fault_domain        = "FAULT-DOMAIN-3"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_in_gbs
  }

  source_details {
    source_type = "image"
    source_id   = var.image_ocid
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.private_subnet.id
    display_name     = "vnic-shared"
    assign_public_ip = false # Purely Private IP (Zero Public IP)
    hostname_label   = "vnic-shared"
    private_ip       = "10.0.0.135"
    nsg_ids          = [oci_core_network_security_group.vm_nsg.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      desired_state = "ENABLED"
      name          = "Bastion"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "OS Management Hub Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }
}
