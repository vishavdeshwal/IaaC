# Fetch all available AZs in current region

data "aws_availability_zones" "available" {}

# -----------
# Public Subnets
#-----------

resource "aws_subnet" "public" {
    for_each = var.public_subnets 

    vpc_id = var.vpc_id
    cidr_block = each.value.cidr
    availability_zone = data.aws_availability_zones.available.names[each.value.az_index]
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.environment}-${var.project}-pub-${each.key}"

    }
}


# ----------
# Private Subnets
# -----------

resource "aws_subnet" "private" {
    for_each = var.private_subnets

    vpc_id = var.vpc_id
    cidr_block = each.value.cidr
    availability_zone = data.aws_availability_zones.available.names[each.value.az_index]

    tags = {
        Name = "${var.environment}-${var.project}-priv-${each.key}"
    }
}


