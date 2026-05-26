# -------
# Subnet Group
# -------

resource "aws_db_subnet_group" "rds" {
    name        = lower("${var.environment}-${var.project}-${var.identifier}-subnet-group")
    subnet_ids  = var.subnet_ids
    description = "RDS subnet group for ${var.identifier}"

    tags = {
        Name        = "${var.environment}-${var.project}-${var.identifier}-subnet-group"
        Environment = var.environment
        Project     = var.project
    }
}


# -------
# RDS Instance
# -------

resource "aws_db_instance" "rds" {
    identifier              = "${var.environment}-${var.project}-${var.identifier}"
    engine                  = var.engine
    engine_version          = var.engine_version
    instance_class          = var.instance_class

    allocated_storage       = var.allocated_storage
    max_allocated_storage   = var.max_allocated_storage
    storage_encrypted       = var.storage_encrypted

    db_name                 = var.db_name
    username                = var.username
    password                = var.password

    db_subnet_group_name    = aws_db_subnet_group.rds.name
    vpc_security_group_ids  = var.security_group_ids

    multi_az                = var.multi_az
    publicly_accessible     = var.publicly_accessible

    backup_retention_period = var.backup_retention_period
    backup_window           = var.backup_window
    maintenance_window      = var.maintenance_window

    skip_final_snapshot     = var.skip_final_snapshot
    deletion_protection     = var.deletion_protection
    apply_immediately       = var.apply_immediately

    tags = {
        Name        = "${var.environment}-${var.project}-${var.identifier}"
        Environment = var.environment
        Project     = var.project
    }
}
