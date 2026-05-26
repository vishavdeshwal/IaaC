output "eip_id" {
    value = aws_eip.eip.id
}

output "public_ip" {
    value = aws_eip.eip.public_ip
}

output "eip_allocation_id" {
    value = aws_eip.eip.allocation_id
}