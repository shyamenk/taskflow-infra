data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Keyed by AZ name so each subnet, NAT and route table has a stable address.
  # With count, deleting the first CIDR would shift every later index and recreate them.
  azs = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidr))

  public_subnets  = { for i, az in local.azs : az => var.public_subnet_cidr[i] }
  private_subnets = { for i, az in local.azs : az => var.private_subnet_cidr[i] }
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "private" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false
  tags = {
    Name                                            = "${var.name}-private-${substr(each.key, -2, 2)}"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags = {
    Name                                            = "${var.name}-public-${substr(each.key, -2, 2)}"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  for_each = local.private_subnets
  vpc_id   = aws_vpc.main.id

  route {
    nat_gateway_id = aws_nat_gateway.nat_gw[each.key].id
    cidr_block     = "0.0.0.0/0"
  }

  tags = {
    Name = "${var.name}-private-rt-${substr(each.key, -2, 2)}"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_association" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_route_table_association" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt[each.key].id
}

resource "aws_eip" "nat_gw_eip" {
  for_each = local.public_subnets
  domain   = "vpc"
  tags = {
    Name = "${var.name}-eip-${substr(each.key, -2, 2)}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat_gw_eip[each.key].id
  subnet_id     = each.value.id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.name}-nat-${substr(each.key, -2, 2)}"
  }
}
