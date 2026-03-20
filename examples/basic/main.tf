terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

module "alb" {
  source = "../.."

  name                    = "example-public-alb"
  vpc_id                  = "vpc-0123456789abcdef0"
  subnets                 = ["subnet-0123456789abcdef0", "subnet-11111111111111111", "subnet-22222222222222222"]
  certificate_arn         = "arn:aws:acm:eu-west-2:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  access_logs_bucket_name = "precreated-alb-access-logs"

  waf_managed_rules = {
    AWSManagedRulesAmazonIpReputationList = false # count mode
  }

  waf_managed_rule_overrides = {
    AWSManagedRulesCommonRuleSet = {
      NoUserAgent_HEADER = "count"
    }
  }

  egress_security_group_ids = {
    app = "sg-0123456789abcdef0"
    cms = "sg-11111111111111111"
  }

  backends = {
    app = {
      domains = [
        "app.example.com",
        "www.example.com",
      ]
      target_group = {
        name_prefix = "app"
        port        = 8080
        health_check = {
          path = "/healthcheck"
        }
      }
    }
    cms = {
      domains = [
        "cms.example.com",
      ]
      target_group = {
        name_prefix = "cms"
        port        = 80
        health_check = {
          path = "/status"
        }
      }
    }
  }
}
