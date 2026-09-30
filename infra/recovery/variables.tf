variable "profile" {
  description = "OCI CLI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "tenancy_ocid" {
  description = "Target tenancy for discovery and recovery IAM."
  type        = string
}

variable "enabled" {
  description = "Enable scheduling after a successful invocation and restore drill."
  type        = bool
  default     = false
}

variable "runtime_version_id" {
  description = "Pinned OCI Python 3.12/OL9 runtime OCID; deliberately no latest fallback."
  type        = string
  validation {
    condition     = startswith(var.runtime_version_id, "ocid1.")
    error_message = "Select an explicit runtime version before planning recovery."
  }
}
