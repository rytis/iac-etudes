
module "transit_gateway" {
  source = "terraform-aws-modules/transit-gateway/aws"

  name = "test-tg"

  vpc_attachments = {
    vpc_a = {
      vpc_id      = var.vpc_a.vpc_id
      subnet_ids  = var.vpc_a.public_subnets
      dns_support = true

      # Ideally we want to use the options below, however... they do not work
      # and require multi stage terraform apply with commenting out blocks of code
      # https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/issues/111
      #
      # tgw_destination_cidr = "10.0.0.0/8"
      # vpc_route_table_ids = var.vpc_a.public_route_table_ids
    }
    vpc_b = {
      vpc_id      = var.vpc_b.vpc_id
      subnet_ids  = var.vpc_b.public_subnets
      dns_support = true

      # Ideally we want to use the options below, however... they do not work
      # and require multi stage terraform apply with commenting out blocks of code
      # https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/issues/111
      #
      # tgw_destination_cidr = "10.0.0.0/8"
      # vpc_route_table_ids = var.vpc_b.public_route_table_ids
    }
  }

  # https://github.com/hashicorp/terraform-provider-aws/issues/7769#issuecomment-508244629
  # requirement that the ec2_transit_gateway resource must have the option allow_external_principals: true.
  # Setting the option to false always raises an error as it is an invalid configuration.
  # The same error is also displayed using the AWS RAM console attempting to set external principals to false.

  ram_allow_external_principals = true

}

# Code below is to create additional routes in each VPC route table so that VPC to VPC
# traffic is routed thorough Transit Gateway. Terraform isn't great at using dynamic
# values in count and for_each, so here we are...

data "aws_route_tables" "vpc_a" {
  vpc_id = var.vpc_a.vpc_id
}

data "aws_route_tables" "vpc_b" {
  vpc_id = var.vpc_b.vpc_id
}

resource "aws_route" "vpc_a" {
  count                  = 3 # length(data.aws_route_tables.vpc_a.ids)
  route_table_id         = tolist(data.aws_route_tables.vpc_a.ids)[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = module.transit_gateway.ec2_transit_gateway_id
}

resource "aws_route" "vpc_b" {
  count                  = 3 # length(data.aws_route_tables.vpc_b.ids)
  route_table_id         = tolist(data.aws_route_tables.vpc_b.ids)[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = module.transit_gateway.ec2_transit_gateway_id
}

