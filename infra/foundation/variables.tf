variable "profile" {
  description = "OCI CLI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "auth" {
  description = "OCI provider authentication method."
  type        = string
  default     = "SecurityToken"
}

variable "tenancy_ocid" {
  description = "Target tenancy; supply via TF_VAR_tenancy_ocid from the authenticated OCI profile."
  type        = string
  validation {
    condition     = startswith(var.tenancy_ocid, "ocid1.tenancy.")
    error_message = "Supply a tenancy OCID, not a child compartment."
  }
}

variable "availability_domain_number" {
  description = "Availability domain to select within the configured region."
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 2, 3], var.availability_domain_number)
    error_message = "Select AD 1, 2, or 3."
  }
}

variable "admin_cidr" {
  description = "Administrator's public IPv4 address, with /32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "Supply one IPv4 address with /32."
  }
}

variable "unupgraded_account_confirmed" {
  description = "Confirm no Pay As You Go upgrade (a free trial qualifies). Does not prevent trial-credit consumption."
  type        = bool
  default     = false
}

variable "identity_domain_name" {
  description = "Existing Identity Domain to use for GitHub federation."
  type        = string
  default     = "Default"
}
