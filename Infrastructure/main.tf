terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}


provider "aws" {
  region = "us-east-1" 
  alias  = "use1"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

  tags = {
    Name = "HAWS-PII-VPC"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    
    tags = {
        Name = "HAWS-PII-IGW"
        Environment = var.environment
        ManagedBy   = "terraform"
    }
  
}

data "aws_availability_zones" "available" {
    provider = aws.use1
    }

resource "aws_subnet" "public_a" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true

    tags = {
        Name = "HAWS-PII-Public-A"
        Environment = var.environment
        ManagedBy   = "terraform"
    }
}

resource "aws_subnet" "private_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.11.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]

    tags = {
        Name = "HAWS-PII-Private-A"
        Environment = var.environment
        ManagedBy   = "terraform"
    }
}

resource "aws_subnet" "public_b" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true

    tags = {
        Name = "HAWS-PII-Public-B"
        Environment = var.environment
        ManagedBy   = "terraform"
    }
}

resource "aws_subnet" "private_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.12.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = {
        Name = "HAWS-PII-Private-B"
        Environment = var.environment
        ManagedBy   = "terraform"
    }
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "HAWS-PII-Public-RT"
        Environment = var.environment
        ManagedBy   = "terraform"
    }
}

resource "aws_route_table_association" "public_a"{
    subnet_id = aws_subnet.public_a.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b"{
    subnet_id = aws_subnet.public_b.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route" "public_igw" {
    route_table_id = aws_route_table.public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

module "datapipeline" {
  source = "../terraform/datapipeline"

  environment = var.environment
  app_name    = var.app_name
  aws_region  = var.aws_region

  existing_vpc_id = aws_vpc.main.id

  existing_subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}