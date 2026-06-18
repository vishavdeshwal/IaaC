output "nat_gateway_id" {
    value = aws_nat_gateway.nat.id
}

output "nat_gateway_public_ip" {
    value = aws_nat_gateway.nat.public_ip
}
