# Networking logic to handle existing or new VPC
data "aws_availability_zones" "available" {}

resource "aws_vpc" "new" {
  count                = var.existing_vpc_id == null ? 1 : 0
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.app_name}-vpc-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "new" {
  count  = var.existing_vpc_id == null ? 1 : 0
  vpc_id = aws_vpc.new[0].id

  tags = {
    Name        = "${var.app_name}-igw-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "public" {
  count                   = var.existing_vpc_id == null ? 2 : 0
  vpc_id                  = aws_vpc.new[0].id
  cidr_block              = "10.1.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-public-subnet-${count.index}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table" "public" {
  count  = var.existing_vpc_id == null ? 1 : 0
  vpc_id = aws_vpc.new[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.new[0].id
  }

  tags = {
    Name        = "${var.app_name}-public-rt-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.existing_vpc_id == null ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

locals {
  vpc_id     = var.existing_vpc_id != null ? var.existing_vpc_id : aws_vpc.new[0].id
  subnet_ids = var.existing_subnet_ids != null ? var.existing_subnet_ids : aws_subnet.public[*].id
}

data "aws_route_table" "selected" {
  count     = var.existing_subnet_ids != null ? length(var.existing_subnet_ids) : 0
  subnet_id = var.existing_subnet_ids[count.index]
}

# Precondition to ensure all existing subnets have a route to 0.0.0.0/0 via IGW or NAT Gateway
resource "null_resource" "check_egress" {
  count = var.existing_subnet_ids != null ? length(var.existing_subnet_ids) : 0

  lifecycle {
    precondition {
      condition = anytrue([
        for r in data.aws_route_table.selected[count.index].routes : (
          r.cidr_block == "0.0.0.0/0" && (
            (r.gateway_id != null && r.gateway_id != "" && can(regex("^igw-", r.gateway_id))) ||
            (r.nat_gateway_id != null && r.nat_gateway_id != "")
          )
        )
      ])
      error_message = "Subnet ${var.existing_subnet_ids[count.index]} does not have a valid outbound route (0.0.0.0/0) via IGW or NAT Gateway."
    }
  }
}

resource "aws_security_group" "batch_sg" {
  name        = "${var.app_name}-batch-sg-${var.environment}"
  description = "Security group for Batch compute environment"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-batch-sg-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
