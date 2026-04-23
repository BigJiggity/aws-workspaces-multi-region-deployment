# ==============================================================================
# AWS WAF (Web Application Firewall)
# ==============================================================================

resource "aws_wafv2_web_acl" "vaultwarden" {
  name        = "${local.name_prefix}-waf"
  description = "WAF for VaultWarden - OWASP Top 10 protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # --------------------------------------------------------------------------
  # RATE LIMITING
  # --------------------------------------------------------------------------
  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # AWS MANAGED RULES - Common Rule Set
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude rules that might interfere with VaultWarden API
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # AWS MANAGED RULES - SQL Injection
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 20

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
      metric_name                = "${local.name_prefix}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # AWS MANAGED RULES - Known Bad Inputs
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 30

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
      metric_name                = "${local.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # AWS MANAGED RULES - Linux OS
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-linux-rules"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # AWS MANAGED RULES - Amazon IP Reputation
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 50

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
      metric_name                = "${local.name_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # AWS MANAGED RULES - Anonymous IP List
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 60

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"

        # Allow VPNs/proxies but block hosting providers
        rule_action_override {
          name = "AnonymousIPList"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-anonymous-ip"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # CUSTOM RULE - Block sensitive paths
  # --------------------------------------------------------------------------
  rule {
    name     = "BlockSensitivePaths"
    priority = 70

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string = "/.env"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
        statement {
          byte_match_statement {
            search_string = "/.git"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
        statement {
          byte_match_statement {
            search_string = "/wp-admin"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
        statement {
          byte_match_statement {
            search_string = "/phpmyadmin"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-block-sensitive"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-waf"
  })
}

# ------------------------------------------------------------------------------
# WAF ASSOCIATION WITH ALB
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "vaultwarden" {
  resource_arn = aws_lb.vaultwarden.arn
  web_acl_arn  = aws_wafv2_web_acl.vaultwarden.arn
}

# ------------------------------------------------------------------------------
# WAF LOGGING
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "vaultwarden" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.vaultwarden.arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "COUNT"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}
