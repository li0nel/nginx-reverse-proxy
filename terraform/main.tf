module "vpc" {
  source            = "./vpc"
  stack_name  = var.stack_name
  b_private_subnets = false
}

module "ec2" {
  source      = "./ec2"
  stack_name  = var.stack_name
  vpc         = module.vpc
}