module "foundation" {
  source       = "../modules/foundation-data"
  tenancy_ocid = var.tenancy_ocid
}

data "oci_identity_compartments" "recovery" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-recovery"
  state          = "ACTIVE"
  lifecycle {
    postcondition {
      condition     = length(self.compartments) == 1
      error_message = "Apply foundation first; expected exactly one recovery compartment."
    }
  }
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  compartment_id = one(data.oci_identity_compartments.recovery.compartments).id
  bucket         = "${local.settings.name}-recovery"
  project        = "${path.module}/../.."
  archive        = "${local.project}/functions/backup/function.zip"
  manifest       = try(jsondecode(file("${local.project}/functions/backup/function.manifest.json")), { inputs = {}, archive_sha256 = "" })
  build_inputs   = setunion(toset(["pyproject.toml", "uv.lock", "mise.toml", "mise.lock", "functions/backup/package.py"]), fileset(local.project, "functions/backup/src/**/*.py"))
}
