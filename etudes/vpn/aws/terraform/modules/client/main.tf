##############################################################################
## Certificates for mutual authentication

# -- CA certificate ----------------------------------------------------------

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing"
  ]

  dns_names = ["ca"]

  subject {
    common_name = "ca"
  }
}

# -- Server certificate ------------------------------------------------------

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  dns_names = ["server"]

  subject {
    common_name = "server"
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem      = tls_cert_request.server.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 87600

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
}

# -- Client certificate ------------------------------------------------------

resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  dns_names = ["client"]

  subject {
    common_name = "client"
  }
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem      = tls_cert_request.client.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 87600

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "aws_acm_certificate" "client" {
  private_key       = tls_private_key.client.private_key_pem
  certificate_body  = tls_locally_signed_cert.client.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
}

##############################################################################
## Client VPN

# in this exercise we'll allow all traffic both ways to and from VPN endpoint
# full egress access allows to connect to antyhing and anywhere on the internet

module "client_vpn_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "client-vpn"
  vpc_id = var.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "client VPN"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = var.client_cidr
  vpc_id                 = var.vpc.vpc_id
  security_group_ids     = [module.client_vpn_sg.security_group_id]

  # DNS server in VPC is always .2 address in VPC subnet
  # https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/troubleshooting.html#no-internet-access

  dns_servers = [cidrhost(var.vpc.vpc_cidr_block, 2)]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client.arn
  }

  self_service_portal = "enabled"

  connection_log_options {
    enabled = false
  }
}

# `vpc.*_subnets` aren't available until vpc resources are created
# so terraform freaks out if we attempt to use those, for example
# in `for_each` or `length`, etc.
# the way around that is to create local variable in wrapped in `try`,
# so that terraform can happily plan knowing it can fail back to
# and empty list, but in real deployment that list will be
# available, and we'll get correct list of subnets
# we still can't use length (even on local var), so need to pass
# as a variable.

locals {
  association_subnets = try(var.vpc.public_subnets, tolist([]))
}

# VPN endpoint needs to be associated with one or more subnets
# effectivelly creating an interface on that subnet.
# one association is sufficient for up to 7k client connections
# but for AZ redundancy purposes we'll associate with all available
# public subnets

resource "aws_ec2_client_vpn_network_association" "this" {
  count                  = var.number_of_associated_subnets
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = local.association_subnets[count.index]
}

# in this excercise we allow VPN access to any network

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = "0.0.0.0/0"
  authorize_all_groups   = true
}

# we also need to create explicit routes in each associated
# subnet to allow access to the internet

resource "aws_ec2_client_vpn_route" "internet" {
  count                  = var.number_of_associated_subnets
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = local.association_subnets[count.index]

  # default is 4, and route management may take considerable amount of time
  timeouts {
    create = "30m"
    delete = "30m"
  }
}

##############################################################################
## Client config

# generate client configuration file to be used in any OpenVPN compatible
# VPN client (OpenVPN, AmazonVPN, Tunnelblick, etc)

resource "local_file" "client_config" {
  content = templatefile("${path.module}/client-config.ovpn.tftpl", {
    ca_cert               = tls_self_signed_cert.ca.cert_pem,
    client_cert           = tls_locally_signed_cert.client.cert_pem,
    client_key            = tls_private_key.client.private_key_pem,
    vpn_endpoint_dns_name = aws_ec2_client_vpn_endpoint.this.dns_name
  })
  filename = "${path.module}/client-config.ovpn"
}
