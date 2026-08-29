########################################################################
# modulo networking
# VPC dedicada ao cluster EKS: subnets publicas (NLB do ingress) e
# privadas (nodes, RDS, ElastiCache), IGW, NAT Gateway(s) e route tables.
########################################################################

locals {
  public_subnets  = { for i, cidr in var.public_subnet_cidrs : i => cidr }
  private_subnets = { for i, cidr in var.private_subnet_cidrs : i => cidr }

  # indices das AZs que recebem NAT Gateway
  nat_indices = var.single_nat_gateway ? [0] : [for i, _ in var.public_subnet_cidrs : i]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc-${var.env}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw-${var.env}"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.name}-public-${var.azs[tonumber(each.key)]}-${var.env}"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.azs[tonumber(each.key)]

  tags = {
    Name                                            = "${var.name}-private-${var.azs[tonumber(each.key)]}-${var.env}"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

########################################################################
# NAT
########################################################################

resource "aws_eip" "nat" {
  for_each = toset([for i in local.nat_indices : tostring(i)])
  domain   = "vpc"

  tags = {
    Name = "${var.name}-nat-eip-${each.key}-${var.env}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = toset([for i in local.nat_indices : tostring(i)])

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name = "${var.name}-nat-${each.key}-${var.env}"
  }
}

########################################################################
# Route tables
########################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-rt-public-${var.env}"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    # com single_nat_gateway todas as privadas apontam para o NAT do indice 0
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this["0"].id : aws_nat_gateway.this[each.key].id
  }

  tags = {
    Name = "${var.name}-rt-private-${each.key}-${var.env}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
