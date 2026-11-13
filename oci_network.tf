# ─── Virtual Cloud Network (VCN) ─────────────────────────────────────────────

resource "oci_core_vcn" "vcn_shared" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "vcn-shared"
  dns_label      = "vcn08142232"
}

# ─── NAT Gateway (Outbound-only internet for Private Subnet) ─────────────────

resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn_shared.id
  display_name   = "nat-gateway-app"
  block_traffic  = false
}

# ─── Internet Gateway (Available for public resources if needed) ─────────────

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn_shared.id
  display_name   = "Internet Gateway vcn-shared"
  enabled        = true
}

# ─── VCN Default Route Table (Routes 0.0.0.0/0 to NAT Gateway) ───────────────
# Built-in VCN default: adopted via manage_default_resource_id (never created
# or deleted by Terraform, so no import is needed).

resource "oci_core_default_route_table" "private_route_table" {
  manage_default_resource_id = oci_core_vcn.vcn_shared.default_route_table_id
  compartment_id             = var.compartment_ocid
  display_name               = "Default Route Table for vcn-shared"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
}

# ─── VCN Default Security List ───────────────────────────────────────────────
# Built-in VCN default: adopted via manage_default_resource_id.

resource "oci_core_default_security_list" "private_security_list" {
  manage_default_resource_id = oci_core_vcn.vcn_shared.default_security_list_id
  compartment_id             = var.compartment_ocid
  display_name               = "Default Security List for vcn-shared"

  # Outbound: Allow all traffic out through NAT Gateway
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Inbound: Allow SSH (Port 22) only from within the VCN (i.e. the OCI Bastion's
  # private endpoint). Never expose 22 to 0.0.0.0/0.
  ingress_security_rules {
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Inbound: ICMP type 3 code 4 (Path MTU discovery) from anywhere
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "1" # ICMP
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Inbound: ICMP type 3 (Destination Unreachable) from within the VCN
  ingress_security_rules {
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "1" # ICMP
    stateless   = false

    icmp_options {
      type = 3
    }
  }
}

# ─── Network Security Group (attached to the VM's VNIC) ──────────────────────

resource "oci_core_network_security_group" "vm_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn_shared.id
  display_name   = "ig-quick-action-NSG"
}

resource "oci_core_network_security_group_security_rule" "vm_nsg_egress_all" {
  network_security_group_id = oci_core_network_security_group.vm_nsg.id
  direction                 = "EGRESS"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  protocol                  = "all"
  stateless                 = false
}

# ─── Subnet (Public IPs permitted; default route is via the NAT Gateway) ─────
# NOTE: prohibit_public_ip_on_vnic / prohibit_internet_ingress are immutable in
# OCI. Flipping them to true forces subnet replacement (destroying the VM and
# Bastion). Change only when rebuilding. A public IP would not work anyway,
# since 0.0.0.0/0 routes to the NAT Gateway.

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn_shared.id
  cidr_block                 = "10.0.0.0/24"
  display_name               = "snet-alwaysfree-vm-public"
  dns_label                  = "subnet08142232"
  route_table_id             = oci_core_default_route_table.private_route_table.id
  security_list_ids          = [oci_core_default_security_list.private_security_list.id]
  prohibit_public_ip_on_vnic = false
  prohibit_internet_ingress  = false
}
