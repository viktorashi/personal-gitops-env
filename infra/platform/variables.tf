variable "profile" {
  description = "OCI CLI session profile."
  type        = string
  default     = "DEFAULT"
}

variable "compartment_id" {
  description = "Platform compartment OCID."
  type        = string
}

variable "vcn_id" {
  description = "Foundation VCN OCID."
  type        = string
}

variable "endpoint_subnet_id" {
  description = "Restricted public API endpoint subnet."
  type        = string
}

variable "worker_subnet_id" {
  description = "Worker subnet with public egress."
  type        = string
}

variable "edge_subnet_id" {
  description = "Public load-balancer subnet."
  type        = string
}

variable "availability_domain" {
  description = "Same AD as the foundation data volume."
  type        = string
}
