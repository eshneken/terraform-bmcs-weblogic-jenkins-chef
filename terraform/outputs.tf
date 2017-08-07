### Output

output "public_ip" {
    value = "${data.baremetal_core_vnic.InstanceVnic.public_ip_address}"
    }
