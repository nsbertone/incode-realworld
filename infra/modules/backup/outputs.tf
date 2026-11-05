output "plan_id" {
  value = aws_backup_plan.this.id
}

output "primary_vault_arn" {
  value = aws_backup_vault.primary.arn
}

output "dr_vault_arn" {
  value = aws_backup_vault.dr.arn
}
