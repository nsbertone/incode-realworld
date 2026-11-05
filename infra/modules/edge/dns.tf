# Only used when var.domain_name is set.

# Viewer certificate for CloudFront (must be in us-east-1).
resource "aws_acm_certificate" "viewer" {
  count    = local.https ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Origin certificate for the ALB (regional).
resource "aws_acm_certificate" "origin" {
  count = local.https ? 1 : 0

  domain_name       = "origin.${var.domain_name}"
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  validation_records = local.https ? merge(
    { for o in aws_acm_certificate.viewer[0].domain_validation_options : "viewer-${o.domain_name}" => o },
    { for o in aws_acm_certificate.origin[0].domain_validation_options : "origin-${o.domain_name}" => o },
  ) : {}
}

resource "aws_route53_record" "validation" {
  for_each = local.validation_records

  zone_id         = var.hosted_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "viewer" {
  count    = local.https ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.viewer[0].arn
  validation_record_fqdns = [for k, r in aws_route53_record.validation : r.fqdn if startswith(k, "viewer-")]
}

resource "aws_acm_certificate_validation" "origin" {
  count = local.https ? 1 : 0

  certificate_arn         = aws_acm_certificate.origin[0].arn
  validation_record_fqdns = [for k, r in aws_route53_record.validation : r.fqdn if startswith(k, "origin-")]
}

resource "aws_route53_record" "origin" {
  count = local.https ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = "origin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "app" {
  count = local.https ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
