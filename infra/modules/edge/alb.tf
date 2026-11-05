# The ALB, listeners and target groups are owned by Terraform. The AWS Load
# Balancer Controller only registers pod IPs into the target groups through
# TargetGroupBinding objects. That keeps CloudFront -> ALB fully in code and
# avoids a two-phase apply (CloudFront needing an ALB that Kubernetes creates).

locals {
  https = var.domain_name != null
  # With a domain, CloudFront talks HTTPS to origin.<domain> (cert on the ALB).
  origin_hostname = local.https ? "origin.${var.domain_name}" : aws_lb.this.dns_name
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "ALB: only CloudFront origin-facing IPs"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = local.https ? 443 : 80
  to_port           = local.https ? 443 : 80
  description       = "CloudFront origin-facing"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_vpc" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = min(var.frontend_port, var.backend_port)
  to_port           = max(var.frontend_port, var.backend_port)
  description       = "To pods (IP targets)"
}

# ---- ALB access logs -> S3 (queryable with Athena later)
data "aws_elb_service_account" "this" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket_prefix = "${var.name}-alb-logs-"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # ALB log delivery does not support SSE-KMS
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration {
      days = var.log_retention_days
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

resource "aws_lb" "this" {
  name               = substr("${var.name}-alb", 0, 32)
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
  idle_timeout               = 60

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }

  tags       = var.tags
  depends_on = [aws_s3_bucket_policy.alb_logs]
}

resource "aws_lb_target_group" "frontend" {
  name                 = substr("${var.name}-fe", 0, 32)
  port                 = var.frontend_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }

  tags = var.tags
}

resource "aws_lb_target_group" "backend" {
  name                 = substr("${var.name}-be", 0, 32)
  port                 = var.backend_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.backend_health_path
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }

  tags = var.tags
}

# Shared secret header: requests that did not come through our CloudFront
# distribution (and therefore through WAF) get a 403, even from other
# CloudFront distributions that share the same prefix list.
resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = local.https ? 443 : 80
  protocol          = local.https ? "HTTPS" : "HTTP"
  ssl_policy        = local.https ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = local.https ? aws_acm_certificate_validation.origin[0].certificate_arn : null

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 10

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_verify.result]
    }
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 20

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_verify.result]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
