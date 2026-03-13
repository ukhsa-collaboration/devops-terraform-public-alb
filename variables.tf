variable "name" {
  description = "Name of the load balancer."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created."
  type        = string
}

variable "subnets" {
  description = "Subnet IDs where the ALB will be placed."
  type        = list(string)
}

variable "internal" {
  description = "Whether the load balancer is internal."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate used by the HTTPS listener."
  type        = string
}

variable "enable_deletion_protection" {
  description = "Whether deletion protection is enabled on the ALB."
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Whether to create and associate a regional AWS WAFv2 Web ACL with the ALB."
  type        = bool
  default     = true
}

variable "access_logs_bucket_name" {
  description = "Name of the pre-created S3 bucket that receives ALB access logs."
  type        = string
}

variable "access_logs_prefix" {
  description = "Optional S3 key prefix for ALB access logs."
  type        = string
  default     = "alb"
}

variable "create_http_redirect" {
  description = "Whether to create an HTTP listener with host-based redirects to HTTPS."
  type        = bool
  default     = true
}

variable "create_http_listener" {
  description = "Whether to create an HTTP listener when redirects are disabled."
  type        = bool
  default     = true
}

variable "ssl_policy" {
  description = "SSL policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
}

variable "backends" {
  description = "Backend definitions for the public ALB. Each declares the frontend hostnames it serves and the target group configuration."
  type        = map(any)

  validation {
    condition     = length(var.backends) > 0 && length(var.backends) <= 5
    error_message = "Provide between 1 and 5 backends."
  }

  validation {
    condition = alltrue([
      for backend in values(var.backends) :
      can(backend.domains) && length(backend.domains) > 0
    ])
    error_message = "Each backend must define at least one frontend domain."
  }

  validation {
    condition = alltrue(flatten([
      for backend in values(var.backends) : [
        for domain in try(backend.domains, []) : trimspace(domain) != ""
      ]
    ]))
    error_message = "Backend domains must not contain empty values."
  }

  validation {
    condition = length(distinct(flatten([
      for backend in values(var.backends) : backend.domains
      ]))) == length(flatten([
      for backend in values(var.backends) : backend.domains
    ]))
    error_message = "Backend domains must be unique across all backends."
  }

  validation {
    condition = length(distinct(flatten([
      for backend in values(var.backends) : backend.domains
    ]))) <= 5
    error_message = "The current HTTP redirect implementation supports up to 5 total frontend domains across all backends. Additional domains require splitting the HTTP redirect across multiple listener rules."
  }

  validation {
    condition = alltrue([
      for backend in values(var.backends) :
      can(backend.target_group) && can(backend.target_group.port)
    ])
    error_message = "Each backend must define target_group.port."
  }
}

variable "security_group_ingress_rules" {
  description = "Ingress security group rules applied to the ALB security group."
  type        = map(any)
  default = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic from Internet"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic from Internet"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

variable "security_group_egress_rules" {
  description = "Egress security group rules applied to the ALB security group."
  type        = map(any)
  default     = {}
}

variable "egress_security_group_ids" {
  description = "Optional map of backend key to security group ID for restricting ALB egress per backend. Backends not present in the map use CIDR-based egress rules."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to the ALB resources."
  type        = map(string)
  default     = {}
}
