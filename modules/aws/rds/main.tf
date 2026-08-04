locals {
  name = lower("${var.environment}-${var.project}-${var.identifier}")

  base_tags = {
    Name        = "${var.environment}-${var.project}-${var.identifier}"
    Environment = var.environment
    Project     = var.project
  }
}

# -------
# Subnet Group
# -------

resource "aws_db_subnet_group" "rds" {
  name        = "${local.name}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "RDS subnet group for ${var.identifier}"

  tags = merge(var.tags, local.base_tags, {
    Name = "${var.environment}-${var.project}-${var.identifier}-subnet-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}


# -------
# RDS Instance
# -------

resource "aws_db_instance" "rds" {
  identifier     = local.name
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = var.storage_encrypted
  storage_type          = var.storage_type
  iops                  = var.iops
  storage_throughput    = var.storage_throughput
  kms_key_id            = var.kms_key_id

  db_name  = var.db_name
  username = var.username

  password                      = var.manage_master_user_password ? null : var.password
  manage_master_user_password   = var.manage_master_user_password ? true : null
  master_user_secret_kms_key_id = var.manage_master_user_password ? var.master_user_secret_kms_key_id : null

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible

  parameter_group_name = var.parameter_group_name
  ca_cert_identifier   = var.ca_cert_identifier
  multi_az             = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = var.copy_tags_to_snapshot

  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(
    var.final_snapshot_identifier,
    "${local.name}-final"
  )

  deletion_protection = var.deletion_protection
  apply_immediately   = var.apply_immediately

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = (
    var.performance_insights_enabled ? var.performance_insights_retention_period : null
  )

  tags = merge(var.tags, local.base_tags)

  timeouts {
    create = "60m"
    update = "120m"
    delete = "60m"
  }
}

