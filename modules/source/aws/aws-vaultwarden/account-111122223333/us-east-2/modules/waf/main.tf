# ==============================================================================
# WAF MODULE - MAIN
# ==============================================================================

# ------------------------------------------------------------------------------
# IP Set for Allowlist (Optional)
# ------------------------------------------------------------------------------
resource "aws_wafv2_ip_set" "allowlist" {
  count = length(var.ip_allowlist) > 0 ? 1 : 0

  name               = "${var.name_prefix}-ip-allowlist"
  description        = "Allowed IP addresses"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.ip_allowlist

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Web ACL
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-waf"
  description = "WAF for VaultWarden"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Rate limiting
  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Common Rule Set
  dynamic "rule" {
    for_each = var.enable_common_ruleset ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 2

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"

          # Exclude rules that may interfere with VaultWarden
          rule_action_override {
            name = "SizeRestrictions_BODY"
            action_to_use {
              count {}
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-common-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 3: AWS Managed Rules - SQL Injection
  dynamic "rule" {
    for_each = var.enable_sqli_ruleset ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-sqli-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 4: AWS Managed Rules - Known Bad Inputs
  dynamic "rule" {
    for_each = var.enable_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-bad-inputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 5: AWS Managed Rules - IP Reputation
  dynamic "rule" {
    for_each = var.enable_ip_reputation ? [1] : []
    content {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 5

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-ip-reputation"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-waf"
  })
}

# ------------------------------------------------------------------------------
# WAF Association with ALB
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for WAF
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = 30

  tags = var.tags
}

# ------------------------------------------------------------------------------
# WAF Logging Configuration
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}
