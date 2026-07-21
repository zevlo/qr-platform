# VPC + 2 AZ of public + private subnets, no NAT gateway (cost discipline).
# Nodes live in public subnets and reach ECR/S3 via VPC gateways.

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = var.name })
}

# ---------- Public subnets ----------

resource "aws_subnet" "public" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[index(var.azs, each.value)]
  availability_zone = each.value

  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.name}-public-${each.value}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route_table_association" "public" {
  for_each = toset(var.azs)

  subnet_id      = aws_subnet.public[each.value].id
  route_table_id = aws_route_table.public.id
}

# ---------- Private subnets (unused by nodes today; future expansion) ----------

resource "aws_subnet" "private" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[index(var.azs, each.value)]
  availability_zone = each.value

  tags = merge(var.tags, {
    Name                              = "${var.name}-private-${each.value}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ---------- VPC endpoints (no NAT, but nodes need to pull images + talk to STS) ----------

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints"
  description = "Ingress from VPC to interface endpoints (ECR, STS)."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name}-vpc-endpoints" })
}

resource "aws_security_group_rule" "vpc_endpoints_ingress" {
  description       = "Allow HTTPS from the VPC to interface endpoints."
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.cidr]
  security_group_id = aws_security_group.vpc_endpoints.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]
}

# ECR interface endpoints (api.ecr, dkr.ecr) so node kubelet can pull images.
# Using interface endpoints costs ~$7/endpoint/mo but is required without NAT.

locals {
  interface_endpoints = [
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.sts",
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)

  vpc_id            = aws_vpc.this.id
  service_name      = each.value
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for s in aws_subnet.public : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
