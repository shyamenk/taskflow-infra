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

resource "aws_route_table" "public_rt" {
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

resource "aws_route_table" "private_rt" {
  count  = length(var.private_subnet_cidr)
  vpc_id = aws_vpc.main.id

  # Route all traffic (0.0.0.0/0) through the NAT gateway in the same AZ
  route {
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
    cidr_block     = "0.0.0.0/0"
  }

  tags = {
    Name = "${var.name}-private-rt-${substr(data.aws_availability_zones.available.names[count.index], -2, 2)}"
  }
}


resource "aws_route_table_association" "public_subnet_route_table_association" {
  count          = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_route_table_association" {
  count          = length(var.private_subnet_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_eip" "nat_gw_eip" {
  count  = length(var.public_subnet_cidr)
  domain = "vpc"
  tags = {
    Name = "${var.name}-eip-${substr(data.aws_availability_zones.available.names[count.index], -2, 2)}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.public_subnet_cidr)
  allocation_id = aws_eip.nat_gw_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.name}-nat-${substr(data.aws_availability_zones.available.names[count.index], -2, 2)}"
  }
}
