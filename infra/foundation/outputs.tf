output "volume_id" {
  description = "Protected source volume."
  value       = oci_core_volume.fns.id
}
