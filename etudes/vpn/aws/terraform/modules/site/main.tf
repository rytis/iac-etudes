
module "transit_gateway" {
  source = "terraform-aws-modules/transit-gateway/aws"

  name = "test-tg"

  vpc_attachments = {
    vpc = {
      vpc_id      = var.vpc.vpc_id
      subnet_ids  = var.vpc.public_subnets
      dns_support = true
      tgw_routes = [
        {
          destination_cidr_block = var.vpc.public_subnets_cidr_blocks[0]
        }
      ]
    }
  }

  # https://github.com/hashicorp/terraform-provider-aws/issues/7769#issuecomment-508244629
  # requirement that the ec2_transit_gateway resource must have the option allow_external_principals: true.
  # Setting the option to false always raises an error as it is an invalid configuration.
  # The same error is also displayed using the AWS RAM console attempting to set external principals to false.

  ram_allow_external_principals = true

}
