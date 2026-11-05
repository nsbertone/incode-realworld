data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.name}-security-headers"
  comment = "HSTS, nosniff, frame deny, referrer policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      protection = true
      mode_block = true
      override   = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  comment         = var.name
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"
  aliases         = local.https ? [var.domain_name] : []
  web_acl_id      = aws_wafv2_web_acl.this.arn

  origin {
    origin_id   = "alb"
    domain_name = local.origin_hostname

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = local.https ? "https-only" : "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_verify.result
    }
  }

  # API: never cached, all methods, forward everything except Host.
  ordered_cache_behavior {
    path_pattern               = "/api/*"
    target_origin_id           = "alb"
    viewer_protocol_policy     = "https-only"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = true
  }

  # Frontend static assets: cached at the edge.
  default_cache_behavior {
    target_origin_id           = "alb"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.https
    acm_certificate_arn            = local.https ? aws_acm_certificate_validation.viewer[0].certificate_arn : null
    ssl_support_method             = local.https ? "sni-only" : null
    minimum_protocol_version       = local.https ? "TLSv1.2_2021" : null
  }

  tags = var.tags
}
