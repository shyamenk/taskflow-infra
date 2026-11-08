resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.name}-vpc"
  }
}


resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidr)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  # tags = {
  #   Name = "${var.name}-private-${count.index}"
  # }
  tags = {
    Name                                            = "${var.name}-private-${substr(data.aws_availability_zones.available.names[count.index], -2, 2)}"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "public" {

  count                   = length(var.public_subnet_cidr)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  # tags = {
  #   Name = "${var.name}-public-${count.index}"
  # }
  tags = {
    Name                                            = "${var.name}-public-${substr(data.aws_availability_zones.available.names[count.index], -2, 2)}"
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

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  # Added: Name tag was missing, so the table had no readable name in the console.
  tags = {
    Name = "${var.name}-public-rt"
  }
}


resource "aws_route_table_association" "public_subnet_route_table_association" {
  count          = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.route_table.id

}


# MISTAKE (commented out): this attached the private subnets to the public route
# table, whose default route goes to the internet gateway. A subnet routed to an
# internet gateway is public, so "private" subnets would not have been private.
# Private subnets get their own route tables through NAT gateways in A5.
# resource "aws_route_table_association" "private_subnet_route_table_association" {
#   count          = length(var.private_subnet_cidr)
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.route_table.id
# }

data "aws_availability_zones" "available" {
  state = "available"
}

