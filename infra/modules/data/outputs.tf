output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_instance_arn" {
  value = aws_db_instance.this.arn
}

output "db_master_secret_arn" {
  description = "RDS-managed secret with username/password (rotated by RDS)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
