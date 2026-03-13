output "alb_arn" {
  description = "ARN of the ALB."
  value       = module.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB."
  value       = module.this.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB."
  value       = module.this.zone_id
}

output "security_group_id" {
  description = "Security group ID created for the ALB."
  value       = module.this.security_group_id
}

output "target_groups" {
  description = "Target groups created by the ALB module."
  value       = module.this.target_groups
}

output "access_logs_bucket_name" {
  description = "S3 bucket name used for ALB access logs."
  value       = var.access_logs_bucket_name
}

output "waf_web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL associated with the ALB."
  value       = try(aws_wafv2_web_acl.this[0].arn, null)
}
