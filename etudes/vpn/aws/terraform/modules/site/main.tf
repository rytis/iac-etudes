module "vpn_gw" {
  source = "terraform-aws-modules/vpn-gateway/aws"

  vpc_id              = var.vpc_a.vpc_id
  transit_gateway_id  = var.transit_gateway.ec2_transit_gateway_id
  customer_gateway_id = var.vpc_a.cgw_ids[0]

  create_vpn_gateway_attachment = false
  connect_to_transit_gateway    = true

  tunnel1_inside_cidr   = "192.168.1.0/30"
  tunnel1_preshared_key = "1234a1234b1234c1234d1234"
}
