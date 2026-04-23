# ==============================================================================
# ELASTIC CONTAINER REGISTRY
# ==============================================================================

resource "aws_ecr_repository" "vaultwarden" {
  name                 = "vaultwarden"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr"
  })
}

# ------------------------------------------------------------------------------
# KMS KEY FOR ECR ENCRYPTION
# ------------------------------------------------------------------------------
resource "aws_kms_key" "ecr" {
  description             = "KMS key for VaultWarden ECR encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-kms"
  })
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${local.name_prefix}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ------------------------------------------------------------------------------
# ECR LIFECYCLE POLICY
# Keep last 10 images, delete untagged after 7 days
# ------------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "vaultwarden" {
  repository = aws_ecr_repository.vaultwarden.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "testing", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECR PULL-THROUGH CACHE (for Docker Hub)
# Automatically caches vaultwarden/server images from Docker Hub
# ------------------------------------------------------------------------------
resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  ecr_repository_prefix = "docker-hub"
  upstream_registry_url = "registry-1.docker.io"

  # Note: For production, configure credentials for Docker Hub to avoid rate limits
  # credential_arn = aws_secretsmanager_secret.docker_hub_credentials.arn
}

# ------------------------------------------------------------------------------
# NULL RESOURCE TO PULL AND PUSH IMAGE
# Pulls vaultwarden image and pushes to ECR
# Run: terraform apply -target=null_resource.push_image
# ------------------------------------------------------------------------------
resource "null_resource" "push_image" {
  triggers = {
    image_tag = var.container_image_tag
    ecr_url   = aws_ecr_repository.vaultwarden.repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      # Login to ECR
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com

      # Pull from Docker Hub
      docker pull vaultwarden/server:${var.container_image_tag}

      # Tag for ECR
      docker tag vaultwarden/server:${var.container_image_tag} ${aws_ecr_repository.vaultwarden.repository_url}:${var.container_image_tag}

      # Push to ECR
      docker push ${aws_ecr_repository.vaultwarden.repository_url}:${var.container_image_tag}
    EOF
  }

  depends_on = [aws_ecr_repository.vaultwarden]
}
