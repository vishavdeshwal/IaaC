resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  user_data                   = var.user_data
  associate_public_ip_address = var.associate_public_ip
  monitoring                  = var.monitoring
  disable_api_termination     = var.disable_api_termination

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = var.root_volume_encrypted
  }

  tags = merge({
    Name        = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
    Environment = var.environment
    Project     = var.project
  }, var.additional_tags)

  volume_tags = merge({
    Name        = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
    Environment = var.environment
    Project     = var.project
  }, var.additional_tags)

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
