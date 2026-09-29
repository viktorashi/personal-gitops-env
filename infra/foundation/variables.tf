variable "profile" {
  description = "OCI CLI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "tenancy_ocid" {
  description = "Home tenancy OCID."
  type        = string
}

variable "availability_domain" {
  description = "Exact Frankfurt availability-domain name for the node and data volume."
  type        = string
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

variable "identity_domain" {
  description = "Administrator-managed domain and confidential application template for GitHub federation."
  type = object({
    id                = string
    url               = string
    oauth_template_id = string
  })
  validation {
    condition     = startswith(var.identity_domain.url, "https://")
    error_message = "Use the Identity Domain's HTTPS URL."
  }
}
