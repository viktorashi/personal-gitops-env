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
