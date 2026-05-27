import re

file_path = "projects/altrx/environments/prod/generated.tf"

with open(file_path, "r") as f:
    content = f.read()

# 1. Clean up subnets
# Remove availability_zone_id, enable_lni_at_device_index, and map_customer_owned_ip_on_launch
content = re.sub(r'\s*availability_zone_id\s*=\s*"[^"]*"', '', content)
content = re.sub(r'\s*enable_lni_at_device_index\s*=\s*\d+', '', content)
content = re.sub(r'\s*map_customer_owned_ip_on_launch\s*=\s*(true|false)', '', content)

# 2. Clean up aws_lb.prod_alb
# Remove subnet_mapping blocks
# Matching: subnet_mapping { ... }
content = re.sub(r'\s*subnet_mapping\s*\{[^}]*\}', '', content)

# 3. Clean up aws_nat_gateway.this
# Replace allocation_id, secondary_allocation_ids, subnet_id
# Remove secondary_private_ip_address_count, secondary_private_ip_addresses
content = re.sub(r'allocation_id\s*=\s*null', 'allocation_id = "eipalloc-0b34c12fc533a8258"', content)
content = re.sub(r'secondary_allocation_ids\s*=\s*\["eipalloc-0b34c12fc533a8258", "eipalloc-0c9d6992f95b637f7"\]', 'secondary_allocation_ids = ["eipalloc-0c9d6992f95b637f7"]', content)
content = re.sub(r'subnet_id\s*=\s*""', 'subnet_id = "subnet-02e5dbd52bb57f9d3"', content)
content = re.sub(r'\s*secondary_private_ip_address_count\s*=\s*\d+', '', content)
content = re.sub(r'\s*secondary_private_ip_addresses\s*=\s*\[\]', '', content)

# 4. Clean up SQS max_message_size
content = re.sub(r'max_message_size\s*=\s*1048576', 'max_message_size = 262144', content)

# 5. Clean up aws_vpc.this
content = re.sub(r'\s*ipv6_netmask_length\s*=\s*\d+', '', content)

# 6. Clean up aws_lb_listener order
content = re.sub(r'\s*order\s*=\s*\d+', '', content)

# 7. Clean up DynamoDB tables point_in_time_recovery
content = re.sub(r'\s*point_in_time_recovery\s*\{[^}]*\}', '', content)

# 8. Clean up aws_elasticache_replication_group.prod_redis
content = re.sub(r'\s*num_node_groups\s*=\s*\d+', '', content)
content = re.sub(r'\s*replicas_per_node_group\s*=\s*\d+', '', content)

# 9. Clean up aws_lb_target_group.prod_backend blocks
content = re.sub(r'\s*target_failover\s*\{[^}]*\}', '', content)
content = re.sub(r'\s*target_health_state\s*\{[^}]*\}', '', content)

with open(file_path, "w") as f:
    f.write(content)

print("generated.tf successfully cleaned up!")
