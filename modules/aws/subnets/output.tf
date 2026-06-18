output "public_subnet_ids" {
  value = {
    for k, subnet in aws_subnet.public :
    k => subnet.id
  }
}

output "private_subnet_ids" {
  value = {
    for k, subnet in aws_subnet.private :
    k => subnet.id
  }
}