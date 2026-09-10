output "bucket_id" {
  value       = aws_s3_bucket.state.id
  description = "The name of the state bucket"
}

output "bucket_arn" {
  value       = aws_s3_bucket.state.arn
  description = "The ARN of the state bucket"
}