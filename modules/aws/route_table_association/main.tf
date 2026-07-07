# ------
# Public Route table Association
# ------

resource "aws_route_table_association" "public" {
  for_each = var.public_subnet_ids

  subnet_id      = each.value
  route_table_id = var.public_route_table_id
}


# ------ 
# Private Route table Association
# ------

resource "aws_route_table_association" "private" {
  for_each = var.private_subnet_ids

  subnet_id      = each.value
  route_table_id = var.private_route_table_id
}