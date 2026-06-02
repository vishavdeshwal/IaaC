# -------
# Subnet Group
# -------

resource "aws_db_subnet_group" "aurora" {
    name        = lower("${var.environment}-${var.project}-${var.cluster_identifier}-subnet-group")
    subnet_ids  = var.subnet_ids
    description = "Aurora subnet group for ${var.cluster_identifier}"

    tags = {
        Name        = "${var.environment}-${var.project}-${var.cluster_identifier}-subnet-group"
        Environment = var.environment
        Project     = var.project
    }
}


# -------
# Aurora Cluster
# -------

resource "aws_rds_cluster" "aurora" {
    cluster_identifier      = lower("${var.environment}-${var.project}-${var.cluster_identifier}")
    engine                  = var.engine
    engine_version          = var.engine_version
    database_name           = var.database_name
    master_username         = var.master_username
    master_password         = var.master_password

    db_subnet_group_name    = aws_db_subnet_group.aurora.name
    vpc_security_group_ids  = var.security_group_ids

    backup_retention_period = var.backup_retention_period
    preferred_backup_window = var.preferred_backup_window
    skip_final_snapshot     = var.skip_final_snapshot
    deletion_protection     = var.deletion_protection
    storage_encrypted       = var.storage_encrypted
    apply_immediately       = var.apply_immediately

    serverlessv2_scaling_configuration {
        min_capacity = var.serverlessv2_min_capacity
        max_capacity = var.serverlessv2_max_capacity
    }

    tags = {
        Name        = "${var.environment}-${var.project}-${var.cluster_identifier}"
        Environment = var.environment
        Project     = var.project
    }

    lifecycle {
        ignore_changes = [engine_version]
    }
}


# -------
# Aurora Cluster Instances
# -------

resource "aws_rds_cluster_instance" "aurora" {
    count = var.num_instances

    identifier          = lower("${var.environment}-${var.project}-${var.cluster_identifier}-${count.index}")
    cluster_identifier  = aws_rds_cluster.aurora.id
    instance_class      = var.instance_class
    engine              = aws_rds_cluster.aurora.engine
    engine_version      = aws_rds_cluster.aurora.engine_version
    apply_immediately   = var.apply_immediately

    tags = {
        Name        = "${var.environment}-${var.project}-${var.cluster_identifier}-${count.index}"
        Environment = var.environment
        Project     = var.project
    }

    lifecycle {
        ignore_changes = [engine_version]
    }
}
