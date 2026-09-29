resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  name               = local.settings.name
  vcn_id             = var.vcn_id
  kubernetes_version = local.settings.kubernetes_version
  type               = "BASIC_CLUSTER"
  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.endpoint_subnet_id
  }
  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }
  options {
    service_lb_subnet_ids = [var.edge_subnet_id]
    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_containerengine_node_pool" "this" {
  compartment_id     = var.compartment_id
  cluster_id         = oci_containerengine_cluster.this.id
  name               = "a1"
  kubernetes_version = local.settings.kubernetes_version
  node_shape         = local.settings.node.shape
  node_shape_config {
    ocpus         = local.settings.node.ocpus
    memory_in_gbs = local.settings.node.memory_gbs
  }
  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.settings.node.image_id
    boot_volume_size_in_gbs = local.settings.node.boot_gbs
  }
  node_config_details {
    size                                = 1
    is_pv_encryption_in_transit_enabled = true
    placement_configs {
      availability_domain = var.availability_domain
      subnet_id           = var.worker_subnet_id
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

output "cluster_id" {
  description = "OKE cluster OCID for kubeconfig generation."
  value       = oci_containerengine_cluster.this.id
}
