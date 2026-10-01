data "oci_functions_functions_runtime_versions" "python" {
  functions_runtime_name       = "python312.ol9"
  functions_runtime_version_id = var.runtime_version_id
  state                        = "ACTIVE"
  lifecycle {
    postcondition {
      condition     = length(flatten(self.functions_runtime_version_collection[*].items)) == 1
      error_message = "The pinned Python runtime must still be ACTIVE."
    }
  }
}

resource "oci_functions_application" "this" {
  compartment_id = local.compartment_id
  display_name   = "gitops-recovery"
  subnet_ids     = [module.foundation.subnet_ids.recovery]
  shape          = "GENERIC_X86"
}

resource "oci_functions_function" "this" {
  application_id     = oci_functions_application.this.id
  display_name       = "fns-backup"
  memory_in_mbs      = 256
  timeout_in_seconds = 120
  config = {
    VOLUME_ID             = module.foundation.volume.id
    SOURCE_COMPARTMENT_ID = module.foundation.compartment_id
    NAMESPACE             = data.oci_objectstorage_namespace.this.namespace
    BUCKET                = local.bucket
    BACKUP_LIMIT          = tostring(local.settings.backup_limit)
  }
  lifecycle {
    precondition {
      condition = try(
        toset(keys(local.manifest.inputs)) == local.build_inputs &&
        alltrue([for path in local.build_inputs : local.manifest.inputs[path] == filesha256("${local.project}/${path}")]) &&
        local.manifest.archive_sha256 == filesha256(local.archive), false
      )
      error_message = "Backup artifact missing, changed, or stale: run mise run package-backup."
    }
  }
  source_details {
    source_type = "ARCHIVE"
    handler     = "func.handler"
    archive_source_details {
      archive_source_type = "DIRECT_ARCHIVE"
      archive_file        = fileexists(local.archive) ? filebase64(local.archive) : null
    }
    runtime_config {
      runtime_config_type          = "MANUAL"
      functions_runtime_name       = data.oci_functions_functions_runtime_versions.python.functions_runtime_name
      functions_runtime_version_id = one(flatten(data.oci_functions_functions_runtime_versions.python.functions_runtime_version_collection[*].items)).id
    }
  }
}

resource "oci_identity_dynamic_group" "this" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-backup"
  description    = "Exact backup function resource principal"
  matching_rule  = "ALL {resource.id = '${oci_functions_function.this.id}'}"
}

resource "oci_identity_policy" "this" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-backup"
  description    = "Source backup rotation and recovery catalog"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.this.name} to use volumes in compartment id ${module.foundation.compartment_id} where target.volume.id = '${module.foundation.volume.id}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.this.name} to manage volume-backups in compartment id ${module.foundation.compartment_id} where any {request.permission = 'VOLUME_BACKUP_CREATE', request.permission = 'VOLUME_BACKUP_INSPECT', request.permission = 'VOLUME_BACKUP_DELETE'}",
    "Allow dynamic-group ${oci_identity_dynamic_group.this.name} to manage objects in compartment id ${local.compartment_id} where target.bucket.name = '${local.bucket}'",
  ]
}

resource "oci_resource_scheduler_schedule" "this" {
  compartment_id     = local.compartment_id
  display_name       = "fns-weekly-backups"
  action             = "START_RESOURCE"
  recurrence_type    = "CRON"
  recurrence_details = "0 * * * *"
  state              = var.enabled ? "ACTIVE" : "INACTIVE"
  resources {
    id = oci_functions_function.this.id
    parameters {
      parameter_type = "BODY"
      value          = [jsonencode({})]
    }
  }
}

resource "oci_identity_policy" "schedule" {
  compartment_id = var.tenancy_ocid
  name           = "gitops-backup-schedule"
  description    = "Only this schedule can invoke the backup function"
  statements = [
    "Allow any-user to use fn-invocation in compartment id ${local.compartment_id} where all {request.principal.type = 'resourceschedule', request.principal.id = '${oci_resource_scheduler_schedule.this.id}', target.function.id = '${oci_functions_function.this.id}'}",
  ]
}

output "function_id" {
  description = "Backup function OCID for manual validation."
  value       = oci_functions_function.this.id
}

output "invoke_endpoint" {
  description = "Regional function invocation endpoint."
  value       = oci_functions_function.this.invoke_endpoint
}
