locals {
  hostname = yamldecode(file("${path.module}/../../cluster/fns/values.yaml")).hostname
}

# Private CA: trust its public certificate on your own devices, never its key.
resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]
  subject {
    common_name = "Personal notes root CA"
  }
}

resource "tls_private_key" "fns" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "fns" {
  private_key_pem = tls_private_key.fns.private_key_pem
  dns_names       = [local.hostname]
  subject {
    common_name = local.hostname
  }
}

resource "tls_locally_signed_cert" "fns" {
  cert_request_pem      = tls_cert_request.fns.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760
  early_renewal_hours   = 720
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "kubernetes_secret_v1" "tls" {
  metadata {
    name      = "fns-tls"
    namespace = kubernetes_namespace_v1.this["fns"].metadata[0].name
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = tls_locally_signed_cert.fns.cert_pem
    "tls.key" = tls_private_key.fns.private_key_pem
    "ca.crt"  = tls_self_signed_cert.ca.cert_pem
  }
}

output "notes_ca_certificate" {
  description = "Public trust anchor to install on personal devices. Not a secret."
  value       = tls_self_signed_cert.ca.cert_pem
}
