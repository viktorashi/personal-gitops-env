variable "profile" {
  description = "OCI CLI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "tenancy_ocid" {
  description = "Tenancy OCID for the function dynamic group and IAM policies."
  type        = string
}

variable "compartment_id" {
  description = "Recovery compartment OCID."
  type        = string
}

variable "source_compartment_id" {
  description = "Compartment containing the source volume and its native backups."
  type        = string
}

variable "subnet_id" {
  description = "Function subnet with service-gateway access."
  type        = string
}

variable "volume_id" {
  description = "Exact protected FNS source volume OCID."
  type        = string
}

variable "namespace" {
  description = "Object Storage namespace."
  type        = string
}

variable "bucket" {
  description = "Recovery catalog and rotation-lock bucket."
  type        = string
}

variable "enabled" {
  description = "Enable scheduling after a successful invocation and restore drill."
  type        = bool
  default     = false
}
