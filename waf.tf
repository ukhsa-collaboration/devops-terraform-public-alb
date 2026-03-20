locals {
  waf_name        = "${var.name}-waf"
  waf_metric_name = replace(substr(local.waf_name, 0, 128), "-", "")
  waf_managed_rule_enforcement_defaults = {
    AWSManagedRulesAmazonIpReputationList = true
    AWSManagedRulesCommonRuleSet          = true
    AWSManagedRulesKnownBadInputsRuleSet  = true
  }
  waf_managed_rule_enforcement = merge(local.waf_managed_rule_enforcement_defaults, var.waf_managed_rules)
  waf_managed_rule_definitions = [
    {
      name          = "AWSManagedRulesAmazonIpReputationList"
      priority      = 10
      metric_suffix = "IpReputation"
    },
    {
      name          = "AWSManagedRulesCommonRuleSet"
      priority      = 20
      metric_suffix = "Common"
    },
    {
      name          = "AWSManagedRulesKnownBadInputsRuleSet"
      priority      = 30
      metric_suffix = "KnownBadInputs"
    },
  ]
}

resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name  = local.waf_name
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.waf_managed_rule_definitions

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = local.waf_managed_rule_enforcement[rule.value.name] ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = local.waf_managed_rule_enforcement[rule.value.name] ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = lookup(var.waf_managed_rule_overrides, rule.value.name, {})

            content {
              name = rule_action_override.key

              action_to_use {
                dynamic "count" {
                  for_each = rule_action_override.value == "count" ? [1] : []
                  content {}
                }

                dynamic "allow" {
                  for_each = rule_action_override.value == "allow" ? [1] : []
                  content {}
                }

                dynamic "block" {
                  for_each = rule_action_override.value == "block" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.waf_metric_name}${rule.value.metric_suffix}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.waf_metric_name
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    {
      Name = local.waf_name
    }
  )
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.enable_waf ? 1 : 0

  resource_arn = module.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
