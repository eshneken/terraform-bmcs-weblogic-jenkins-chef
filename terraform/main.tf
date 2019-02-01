### Declare full network with single AD and compute instance

# VCN
resource "oci_core_virtual_network" "SingleInstanceVCN" {
  cidr_block     = "${var.VPC-CIDR}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "${var.identifier}-docker-wls"
}

# Internet Gateway
resource "oci_core_internet_gateway" "SingleInstanceIGW" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "${var.identifier}-docker-wls-igw"
  vcn_id         = "${oci_core_virtual_network.SingleInstanceVCN.id}"
}

# Routing Table
resource "oci_core_route_table" "SingleInstanceRoutingTable" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.SingleInstanceVCN.id}"
  display_name   = "${var.identifier}-docker-wls-route-table"

  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.SingleInstanceIGW.id}"
  }
}

# Security List
resource "oci_core_security_list" "SingleInstanceSecList" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "${var.identifier}-docker-wls-seclist"
  vcn_id         = "${oci_core_virtual_network.SingleInstanceVCN.id}"

  egress_security_rules = [{
    protocol    = "6"
    destination = "0.0.0.0/0"
  },
    {
      protocol    = "1"
      destination = "0.0.0.0/0"
    },
  ]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      icmp_options {
        "type" = 0
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 3
        "code" = 4
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 8
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
    tcp_options {
        "max" = 80
        "min" = 80
    }
    protocol = "6"
    source = "0.0.0.0/0"
    },
    {
    tcp_options {
        "max" = 443
        "min" = 443
    }
    protocol = "6"
    source = "0.0.0.0/0"
    },
    {
    tcp_options {
        "max" = 7001
        "min" = 7001
    }
    protocol = "6"
    source = "0.0.0.0/0"
    }
  ]
}

# Availability Domain
resource "oci_core_subnet" "SingleInstanceAD1" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.ad - 1],"name")}"
  cidr_block          = "10.0.1.0/24"
  display_name        = "${var.identifier}-docker-wls-ad-1"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_virtual_network.SingleInstanceVCN.id}"
  route_table_id      = "${oci_core_route_table.SingleInstanceRoutingTable.id}"
  security_list_ids   = ["${oci_core_security_list.SingleInstanceSecList.id}"]
  dhcp_options_id     = "${oci_core_virtual_network.SingleInstanceVCN.default_dhcp_options_id}"
}

# Compute Instance
resource "oci_core_instance" "SingleInstance-Compute-1" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.ad - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.identifier}-docker-wls-server"
  image               = "${lookup(data.oci_core_images.OLImageOCID.images[0], "id")}"

  metadata {
    ssh_authorized_keys = "${file(var.ssh_public_key_path)}"
  }
  shape     = "VM.Standard2.1"
  subnet_id = "${oci_core_subnet.SingleInstanceAD1.id}"
}

### Display Public IP of Instance

# Gets a list of vNIC attachments on the instance
data "oci_core_vnic_attachments" "InstanceVnics" {
compartment_id = "${var.compartment_ocid}"
availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.ad - 1],"name")}"
instance_id = "${oci_core_instance.SingleInstance-Compute-1.id}"
}

# Gets the OCID of the first (default) vNIC
data "oci_core_vnic" "InstanceVnic" {
vnic_id = "${lookup(data.oci_core_vnic_attachments.InstanceVnics.vnic_attachments[0],"vnic_id")}"
}

### Provision Server with Chef -> Run Weblogic Docker Recipe
resource "null_resource" "managed_server_instance_config" {
  provisioner "chef"  {
          attributes_json = <<-EOF
            {
            "docker_registry_ip_and_port" : "${file(var.docker_registry_location_path)}",
            "docker_application_tag" : "${var.docker_application_tag}"
            }
          EOF

          on_failure = "continue"
          run_list = ["bmcs_servers::docker_weblogic"]
          node_name = "${var.identifier}-docker-wls-server"
          server_url = "${var.chef_server_url}"
          version = "13.8.5"
          recreate_client = true
          user_name = "${var.chef_username}"
          user_key = "${file(var.chef_private_key)}"

          connection {
            host = "${data.oci_core_vnic.InstanceVnic.public_ip_address}"
            type = "ssh"
            user = "opc"
            private_key = "${file(var.ssh_private_key_path)}"
            }
        }

}
