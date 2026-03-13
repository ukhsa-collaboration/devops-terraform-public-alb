# Public ALB Terraform Module

This module provisions an opinionated public-facing Application Load Balancer on AWS.

It is designed for internet-facing workloads where the ALB should fail closed by default:

- HTTP returns `404` unless the `Host` header matches a configured domain, in which case it redirects to HTTPS
- HTTPS returns `404` unless the `Host` header matches one of the configured backend domains
- routing is driven from a single `backends` map, with up to 5 backend definitions
- access logs are written to a pre-created S3 bucket
- a regional WAFv2 Web ACL is created and associated by default

## Key Features

### Host-Based Routing With a Closed Default
The module derives listener rules from `backends`, where each backend declares the domains it serves and its target group settings.

Requests for unrecognised hostnames are not forwarded:

- HTTP: `404` by default, with redirect to HTTPS only for served domains
- HTTPS: `404` by default, with forwarding only for served domains

Note: the HTTP redirect implementation is constrained by ALB listener-rule match limits. In practice this module supports up to 5 total domains across all backends before the HTTP redirect rule must be split across multiple rules. See AWS ALB rule quotas and condition limits: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-limits.html and https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-condition-types.html

### Opinionated Public ALB Defaults
This module is a wrapper around `terraform-aws-modules/alb/aws` but does not expose all variables to keep it opininated.

Defaults include:

- public ingress on `80` and `443`
- HTTPS listener with `ELBSecurityPolicy-TLS13-1-2-Res-2021-06`
- target groups using `HTTP`, `ip` targets, and `/healthcheck`
- WAFv2 enabled by default with AWS managed baseline rule groups

### Per-Backend Egress Restriction
Egress rules are derived from backend target group ports. By default they allow traffic to `0.0.0.0/0`, but you can restrict individual backends to specific security groups via `egress_security_group_ids`.

## What it does

- Creates an internet-facing ALB unless `internal = true`
- Creates one target group per backend
- Creates host-header HTTPS listener rules from backend definitions
- Redirects HTTP to HTTPS only for served hostnames
- Returns `404` for unmatched HTTP and HTTPS requests
- Enables ALB access logs to a pre-created S3 bucket
- Creates and associates a regional WAFv2 Web ACL by default

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | terraform-aws-modules/alb/aws | v10.5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_lb_listener_rule.http_redirect_served_hosts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_logs_bucket_name"></a> [access\_logs\_bucket\_name](#input\_access\_logs\_bucket\_name) | Name of the pre-created S3 bucket that receives ALB access logs. | `string` | n/a | yes |
| <a name="input_access_logs_prefix"></a> [access\_logs\_prefix](#input\_access\_logs\_prefix) | Optional S3 key prefix for ALB access logs. | `string` | `"alb"` | no |
| <a name="input_backends"></a> [backends](#input\_backends) | Backend definitions for the public ALB. Each declares the frontend hostnames it serves and the target group configuration. | `map(any)` | n/a | yes |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of the ACM certificate used by the HTTPS listener. | `string` | n/a | yes |
| <a name="input_create_http_listener"></a> [create\_http\_listener](#input\_create\_http\_listener) | Whether to create an HTTP listener when redirects are disabled. | `bool` | `true` | no |
| <a name="input_create_http_redirect"></a> [create\_http\_redirect](#input\_create\_http\_redirect) | Whether to create an HTTP listener with host-based redirects to HTTPS. | `bool` | `true` | no |
| <a name="input_egress_security_group_ids"></a> [egress\_security\_group\_ids](#input\_egress\_security\_group\_ids) | Optional map of backend key to security group ID for restricting ALB egress per backend. Backends not present in the map use CIDR-based egress rules. | `map(string)` | `{}` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Whether deletion protection is enabled on the ALB. | `bool` | `false` | no |
| <a name="input_enable_waf"></a> [enable\_waf](#input\_enable\_waf) | Whether to create and associate a regional AWS WAFv2 Web ACL with the ALB. | `bool` | `true` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Whether the load balancer is internal. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the load balancer. | `string` | n/a | yes |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | Egress security group rules applied to the ALB security group. | `map(any)` | `{}` | no |
| <a name="input_security_group_ingress_rules"></a> [security\_group\_ingress\_rules](#input\_security\_group\_ingress\_rules) | Ingress security group rules applied to the ALB security group. | `map(any)` | <pre>{<br/>  "all_http": {<br/>    "cidr_ipv4": "0.0.0.0/0",<br/>    "description": "HTTP web traffic from Internet",<br/>    "from_port": 80,<br/>    "ip_protocol": "tcp",<br/>    "to_port": 80<br/>  },<br/>  "all_https": {<br/>    "cidr_ipv4": "0.0.0.0/0",<br/>    "description": "HTTPS web traffic from Internet",<br/>    "from_port": 443,<br/>    "ip_protocol": "tcp",<br/>    "to_port": 443<br/>  }<br/>}</pre> | no |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | SSL policy for the HTTPS listener. | `string` | `"ELBSecurityPolicy-TLS13-1-2-Res-2021-06"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet IDs where the ALB will be placed. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the ALB resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the ALB will be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_logs_bucket_name"></a> [access\_logs\_bucket\_name](#output\_access\_logs\_bucket\_name) | S3 bucket name used for ALB access logs. |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the ALB. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the ALB. |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route53 zone ID of the ALB. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID created for the ALB. |
| <a name="output_target_groups"></a> [target\_groups](#output\_target\_groups) | Target groups created by the ALB module. |
| <a name="output_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#output\_waf\_web\_acl\_arn) | ARN of the WAFv2 Web ACL associated with the ALB. |
<!-- END_TF_DOCS -->

## Usage

```hcl
module "alb" {
  source = "git@github.com:ukhsa-collaboration/devops-terraform-public-alb.git"

  name                    = "example-public-alb"
  vpc_id                  = data.aws_vpc.main.id
  subnets                 = data.aws_subnets.public.ids
  certificate_arn         = aws_acm_certificate.example.arn
  access_logs_bucket_name = "precreated-alb-access-logs"

  backends = {
    app = {
      domains = ["app.example.com"]
      target_group = {
        name_prefix = "app"
        port        = 8080
      }
    }
    cms = {
      domains = ["cms.example.com", "cms-alt.example.com"]
      target_group = {
        name_prefix = "cms"
        port        = 80
      }
    }
  }
}
```
