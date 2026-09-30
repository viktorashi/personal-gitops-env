variable "auth" {
  description = "SecurityToken locally; WorkloadIdentityFederation in GitHub Actions."
  type        = string
  default     = "SecurityToken"
}

variable "profile" {
  description = "OCI CLI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "tenancy_ocid" {
  description = "Target tenancy for live foundation discovery."
  type        = string
}

variable "namespace" {
  description = "Object Storage account namespace; needed before provider initialization."
  type        = string
}
