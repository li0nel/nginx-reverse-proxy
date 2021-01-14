data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

locals {
  nb_azs = length(data.aws_availability_zones.available.names)
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

// Public subnets
resource "aws_subnet" "public_subnets" {
  count             = local.nb_azs
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_route_table" "public_routetable" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "public_rt_associations" {
  count          = local.nb_azs
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_routetable.id
}

// Private subnets
resource "aws_eip" "eips" {
  count = var.b_private_subnets == true ? 1 : 0
  vpc   = true
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = var.b_private_subnets == true ? 1 : 0
  allocation_id = aws_eip.eips.0.id
  subnet_id     = aws_subnet.public_subnets.0.id

  depends_on = [aws_internet_gateway.internet_gateway]
}

resource "aws_subnet" "private_subnets" {
  count             = var.b_private_subnets == true ? local.nb_azs : 0
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + local.nb_azs)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_route_table" "private_routetable" {
  count = var.b_private_subnets == true ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.0.id
  }
}

resource "aws_route_table_association" "private_rt_associations" {
  count          = var.b_private_subnets == true ? 1 : 0
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_routetable.0.id
}