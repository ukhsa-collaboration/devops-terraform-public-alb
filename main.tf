locals {
  default_target_group = {
    protocol          = "HTTP"
    target_type       = "ip"
    create_attachment = false
    health_check = {
      enabled             = true
      interval            = 30
      path                = "/healthcheck"
      port                = "traffic-port"
      healthy_threshold   = 3
      unhealthy_threshold = 3
      timeout             = 6
      protocol            = "HTTP"
      matcher             = "200-399"
    }
  }

  backend_keys = sort(keys(var.backends))
  backend_name_prefixes = {
    for backend_key in local.backend_keys :
    backend_key => substr(
      "${trimsuffix(replace(lower(backend_key), "/[^a-z0-9]/", ""), "-")}tg",
      0,
      6
    )
  }
  target_groups = {
    for backend_key, backend in var.backends :
    backend_key => merge(
      local.default_target_group,
      backend.target_group,
      {
        name_prefix = coalesce(try(backend.target_group.name_prefix, null), local.backend_name_prefixes[backend_key])
        health_check = merge(
          local.default_target_group.health_check,
          try(backend.target_group.health_check, {})
        )
      }
    )
  }
  served_host_headers = distinct(flatten([
    for backend_key in local.backend_keys : var.backends[backend_key].domains
  ]))
  derived_https_listener_rules = {
    for index, backend_key in local.backend_keys :
    "backend-${backend_key}" => {
      priority = index + 100
      actions = [{
        forward = {
          target_group_key = backend_key
        }
      }]
      conditions = [{
        host_header = {
          values = var.backends[backend_key].domains
        }
      }]
    }
  }
  derived_security_group_egress_rules = {
    for rule in distinct([
      for backend_key, target_group in local.target_groups : jsonencode({
        rule_name = lookup(var.egress_security_group_ids, backend_key, null) == null ? "backend_port_${target_group.port}" : "backend_port_${target_group.port}_sg_${lookup(var.egress_security_group_ids, backend_key, null)}"
        rule = {
          from_port                    = target_group.port
          to_port                      = target_group.port
          ip_protocol                  = "tcp"
          description                  = "Application traffic to backend targets"
          cidr_ipv4                    = lookup(var.egress_security_group_ids, backend_key, null) == null ? "0.0.0.0/0" : null
          referenced_security_group_id = lookup(var.egress_security_group_ids, backend_key, null)
        }
      })
    ]) :
    jsondecode(rule).rule_name => jsondecode(rule).rule
  }
  merged_security_group_egress_rules = merge(
    local.derived_security_group_egress_rules,
    var.security_group_egress_rules
  )
  effective_security_group_egress_rules = {
    for rule_name, rule in local.merged_security_group_egress_rules :
    rule_name => merge(
      rule,
      {
        cidr_ipv6      = null
        prefix_list_id = null
      }
    )
  }
}

module "this" {
  source  = "terraform-aws-modules/alb/aws"
  version = "v10.5.0"

  name     = var.name
  vpc_id   = var.vpc_id
  subnets  = var.subnets
  internal = var.internal

  enable_deletion_protection = var.enable_deletion_protection

  security_group_ingress_rules = var.security_group_ingress_rules
  security_group_egress_rules  = local.effective_security_group_egress_rules
  target_groups                = local.target_groups
  access_logs = {
    bucket  = var.access_logs_bucket_name
    enabled = true
    prefix  = var.access_logs_prefix
  }

  listeners = merge(
    var.create_http_redirect ? {
      http = {
        port     = 80
        protocol = "HTTP"

        fixed_response = {
          content_type = "text/plain"
          message_body = "Not Found"
          status_code  = "404"
        }
      }
      } : var.create_http_listener ? {
      http = {
        port     = 80
        protocol = "HTTP"

        fixed_response = {
          content_type = "text/plain"
          message_body = "Not Found"
          status_code  = "404"
        }
      }
    } : {},
    {
      https = {
        port            = 443
        protocol        = "HTTPS"
        certificate_arn = var.certificate_arn
        ssl_policy      = var.ssl_policy

        fixed_response = {
          content_type = "text/plain"
          message_body = "Not Found"
          status_code  = "404"
        }

        rules = local.derived_https_listener_rules
      }
    }
  )

  tags = var.tags
}

resource "aws_lb_listener_rule" "http_redirect_served_hosts" {
  count = var.create_http_redirect && length(local.served_host_headers) > 0 ? 1 : 0

  listener_arn = module.this.listeners["http"].arn
  priority     = 100

  action {
    type = "redirect"

    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = local.served_host_headers
    }
  }
}
