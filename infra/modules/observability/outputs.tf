output "loki_bucket" {
  value = aws_s3_bucket.loki.bucket
}

output "loki_bucket_arn" {
  value = aws_s3_bucket.loki.arn
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
