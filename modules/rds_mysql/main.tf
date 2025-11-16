
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name   = "${var.name}-rds-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Look up a valid MySQL 8.0 engine version for this region
data "aws_rds_engine_version" "mysql_8" {
  engine  = "mysql"
  version = "8.0"        # major line (let AWS return the preferred minor)
  # You can also filter by parameter group family or status if needed
}


resource "aws_db_instance" "this" {
  identifier              = "${var.name}-mysql"
  engine                  = "mysql"
  engine_version          = data.aws_rds_engine_version.mysql_8.version_actual
  instance_class          = "db.t3.micro"
  db_name                 = "banking"
  username                = "admin"
  password                = "changeme-override-in-tfvars" # placeholder, not used (we don't expose here)
  allocated_storage       = var.allocated_storage
  multi_az                = var.multi_az
  publicly_accessible     = false
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  apply_immediately       = true
}
