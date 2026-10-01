terraform {
  required_version = "~> 1.12"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "9.7.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

variable "tenancy_ocid" {
  description = "Target tenancy discovered by mise for human bootstrap."
  type        = string
}

variable "profile" {
  description = "Human OCI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "kubeconfig" {
  description = "Explicit kubeconfig for the target OKE cluster."
  type        = string
}

provider "oci" {
  region              = jsondecode(file("${path.module}/../settings.json")).region
  auth                = "SecurityToken"
  config_file_profile = var.profile
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

module "foundation" {
  source       = "../modules/foundation-data"
  tenancy_ocid = var.tenancy_ocid
}

resource "kubernetes_namespace_v1" "this" {
  for_each = toset(["argocd", "fns"])
  metadata {
    name = each.key
  }
  lifecycle {
    prevent_destroy = true
  }
}

# Human-owned binding, outside the FNS project's allowed resource kinds.
resource "kubernetes_persistent_volume_v1" "fns" {
  metadata {
    name = "fns-data"
  }
  spec {
    capacity                         = { storage = "${module.foundation.volume.size_in_gbs}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = ""
    claim_ref {
      namespace = kubernetes_namespace_v1.this["fns"].metadata[0].name
      name      = "fns-data"
    }
    persistent_volume_source {
      csi {
        driver        = "blockvolume.csi.oraclecloud.com"
        volume_handle = module.foundation.volume.id
        fs_type       = "ext4"
        volume_attributes = {
          attachment-type = "paravirtualized"
        }
      }
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_persistent_volume_claim_v1" "fns" {
  metadata {
    name      = "fns-data"
    namespace = kubernetes_namespace_v1.this["fns"].metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.fns.metadata[0].name
    storage_class_name = ""
    resources {
      requests = { storage = "${module.foundation.volume.size_in_gbs}Gi" }
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}
