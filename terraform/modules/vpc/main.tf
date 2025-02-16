resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = "${var.region}-${var.environment}-vpc"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.region}-${var.environment}-igw"
  }
}

resource "aws_subnet" "private_zones" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                                         = "${var.region}-${var.environment}-private-${count.index}"
    "kubernetes.io/role/internal-elb"                            = "1"
    "kubernetes.io/cluster/${var.region}-${var.environment}-eks" = "owned"
    "karpenter.sh/discovery"                                     = "${var.region}-${var.environment}-eks"
  }

}

resource "aws_subnet" "public_zones" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                         = "${var.region}-${var.environment}-public-${count.index}"
    "kubernetes.io/role/elb"                                     = "1"
    "kubernetes.io/cluster/${var.region}-${var.environment}-eks" = "owned"
  }

}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.region}-${var.environment}-nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zones[0].id

  tags = {
    Name = "${var.region}-${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.region}-${var.environment}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_zones[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.region}-${var.environment}-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_zones[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "karpenter" {
  name   = "${var.region}-${var.environment}-karpenter-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    "Name"                   = "${var.region}-${var.environment}-karpenter-sg"
    "karpenter.sh/discovery" = "${var.region}-${var.environment}-eks"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.karpenter.id]
  subnet_ids          = aws_subnet.private_zones[*].id
  private_dns_enabled = true

  tags = {
    Name = "${var.region}-${var.environment}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.karpenter.id]
  subnet_ids          = aws_subnet.private_zones[*].id
  private_dns_enabled = true

  tags = {
    Name = "${var.region}-${var.environment}-ssm-messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.karpenter.id]
  subnet_ids          = aws_subnet.private_zones[*].id
  private_dns_enabled = true

  tags = {
    Name = "${var.region}-${var.environment}-ec2-messages-endpoint"
  }
}

