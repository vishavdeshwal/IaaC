resource "aws_docdb_subnet_group" "default" {
  name       = lower("${var.cluster_identifier}-subnet-group")
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.cluster_identifier}-subnet-group"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_docdb_cluster" "cluster" {
  cluster_identifier      = lower(var.cluster_identifier)
  engine                  = "docdb"
  master_username         = var.master_username
  master_password         = var.master_password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  vpc_security_group_ids  = var.vpc_security_group_ids
  db_subnet_group_name    = aws_docdb_subnet_group.default.name

  tags = {
    Name        = var.cluster_identifier
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = var.instance_count
  identifier         = lower("${var.cluster_identifier}-${count.index}")
  cluster_identifier = aws_docdb_cluster.cluster.id
  instance_class     = var.instance_class

  tags = {
    Name        = "${var.cluster_identifier}-${count.index}"
    Environment = var.environment
    Project     = var.project
  }
}
