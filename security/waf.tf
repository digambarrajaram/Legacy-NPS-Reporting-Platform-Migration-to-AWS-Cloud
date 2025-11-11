/*
security/waf.tf

Example AWS WAFv2 WebACL (regional) with:
 - AWS managed rule group (Core rule set)
 - Rate-based rule to protect against floods
 - Optional rule to block suspicious IPs (IP Set)
 - Association to an ALB (replace ALB ARN placeholder)

Notes:
 - This example uses the "REGIONAL" scope for ALB. For CloudFront use "CLOUDFRONT" and global resources.
 - Replace placeholders: YOUR_REGION, YOUR_ACCOUNT_ID, YOUR_ALB_ARN, YOUR_KMS_ARN_IF_NEEDED
 - Test in staging before applying to prod.
*/

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the Application Load Balancer to associate WAF with"
  default     = "arn:aws:elasticloadbalancing:REGION:ACCOUNT_ID:loadbalancer/app/YOUR_ALB_NAME/XXXXXXXXXXXX"
}

# Optional: Managed IP Set (blocklist)
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "reporting-blocked-ips"
  description        = "IPs blocked by security team / automation"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = [] # e.g., ["1.2.3.4/32"]
}

# Web ACL
resource "aws_wafv2_web_acl" "reporting_acl" {
  name        = "reporting-web-acl"
  description = "WAF for reporting public endpoints"
  scope       = "REGIONAL" # use CLOUDFRONT for CloudFront distributions
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "reporting-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
    }
  }

  rule {
    name     = "RateLimit_100_per_5m"
    priority = 2
    statement {
      rate_based_statement {
        limit              = 1000  # requests per 5-minute period (tune for your traffic)
        aggregate_key_type = "IP"
      }
    }
    action {
      block {}
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-1000"
    }
  }

  # Example: block specific IPs using IP Set
  dynamic "rule" {
    for_each = length(aws_wafv2_ip_set.blocked_ips.addresses) > 0 ? [1] : []
    content {
      name     = "BlockListedIPs"
      priority = 3
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocked_ips.arn
        }
      }
      action {
        block {}
      }
      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "blocked-ips"
      }
    }
  }

  tags = {
    Project = "nps-reporting"
    Env     = "prod"
  }
}

# Associate WAF with ALB (Regional)
resource "aws_wafv2_web_acl_association" "reporting_alb_assoc" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.reporting_acl.arn
}
