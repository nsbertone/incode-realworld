# CloudFront-scoped Web ACL (lives in us-east-1).
locals {
  managed_rule_groups = [
    # name, priority, rule names forced to COUNT (tuned to avoid false positives)
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 10, count_rules = [] },
    # Article bodies can exceed the 8 KB body-size rule; count it instead of blocking.
    { name = "AWSManagedRulesCommonRuleSet", priority = 20, count_rules = ["SizeRestrictions_BODY"] },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 30, count_rules = [] },
    { name = "AWSManagedRulesSQLiRuleSet", priority = 40, count_rules = [] },
  ]
}

resource "aws_wafv2_web_acl" "this" {
  provider = aws.us_east_1

  name  = "${var.name}-edge"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.managed_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.value.count_rules
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  # Anonymous IPs (VPNs, Tor, hosting providers): observe only.
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 50

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  # Brute-force protection on login.
  rule {
    name     = "rate-limit-login"
    priority = 60

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.login_rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = "/api/users/login"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-login"
      sampled_requests_enabled   = true
    }
  }

  # Generic flood / scraping protection.
  rule {
    name     = "rate-limit-global"
    priority = 70

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.global_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-global"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-edge"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "waf" {
  provider = aws.us_east_1

  # WAF requires the aws-waf-logs- prefix.
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  provider = aws.us_east_1

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}
