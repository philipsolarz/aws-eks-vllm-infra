module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.region}-${var.environment}-vpc"
  cidr = var.cidr_block

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    "Name" = "${var.region}-${var.environment}-vpc"
  }

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  enable_vpn_gateway = var.enable_vpn_gateway

  public_subnet_tags = var.public_subnet_tags

  private_subnet_tags = var.private_subnet_tags
}

# resource "aws_vpc" "main" {
#   cidr_block = var.cidr_block

#   enable_dns_support   = var.enable_dns_support
#   enable_dns_hostnames = var.enable_dns_hostnames

#   tags = {
#     Name = "${var.region}-${var.environment}-vpc"
#   }

# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = module.vpc.vpc_id

#   tags = {
#     Name = "${var.region}-${var.environment}-igw"
#   }
# }

# resource "aws_subnet" "private_zones" {
#   count = length(var.private_subnet_cidrs)

#   vpc_id                  = module.vpc.vpc_id
#   cidr_block              = var.private_subnet_cidrs[count.index]
#   availability_zone       = var.availability_zones[count.index]
#   map_public_ip_on_launch = false

#   tags = {
#     Name                                        = "${var.region}-${var.environment}-private-${count.index}"
#     "kubernetes.io/role/internal-elb"           = "1"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }

# }

# resource "aws_subnet" "public_zones" {
#   count = length(var.public_subnet_cidrs)

#   vpc_id                  = module.vpc.vpc_id
#   cidr_block              = var.public_subnet_cidrs[count.index]
#   availability_zone       = var.availability_zones[count.index]
#   map_public_ip_on_launch = true

#   tags = {
#     Name                                        = "${var.region}-${var.environment}-public-${count.index}"
#     "kubernetes.io/role/elb"                    = "1"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }

# }

# resource "aws_eip" "nat" {
#   domain = "vpc"

#   tags = {
#     Name = "${var.region}-${var.environment}-nat"
#   }
# }

# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public_zones[0].id

#   tags = {
#     Name = "${var.region}-${var.environment}-nat"
#   }

#   depends_on = [aws_internet_gateway.igw]
# }

# resource "aws_route_table" "private" {
#   vpc_id = module.vpc.vpc_id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat.id
#   }

#   tags = {
#     Name = "${var.region}-${var.environment}-private"
#   }
# }

# resource "aws_route_table_association" "private" {
#   count          = length(var.private_subnet_cidrs)
#   subnet_id      = aws_subnet.private_zones[count.index].id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table" "public" {
#   vpc_id = module.vpc.vpc_id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }

#   tags = {
#     Name = "${var.region}-${var.environment}-public"
#   }
# }

# resource "aws_route_table_association" "public" {
#   count          = length(var.public_subnet_cidrs)
#   subnet_id      = aws_subnet.public_zones[count.index].id
#   route_table_id = aws_route_table.public.id
# }
# 1
