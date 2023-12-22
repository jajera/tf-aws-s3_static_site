variable "use_case" {
  default = "tf-aws-s3-static-website"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example-${random_string.suffix.result}"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        },
        {
          "Key": "UseCase",
          "Values": ["${var.use_case}"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name    = "tf-rg-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}


resource "aws_s3_bucket" "example" {
  bucket        = "tf-s3-example-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket_website_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = aws_s3_bucket.example.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.example.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]
}

resource "null_resource" "copy_webfiles" {
  # triggers = {
  #   always_run = timestamp()
  # }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp external/index.html  s3://tf-s3-example-${random_string.suffix.result}
    EOT
  }

  depends_on = [
    aws_s3_bucket_acl.example
  ]
}

data "aws_iam_policy_document" "s3_allow_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.example.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "s3_allow_access" {
  bucket = aws_s3_bucket.example.id
  policy = data.aws_iam_policy_document.s3_allow_access.json

  depends_on = [
    null_resource.copy_webfiles
  ]
}

output "website_url" {
  value = "http://${aws_s3_bucket.example.bucket}.s3-website.${data.aws_region.current.name}.amazonaws.com"
}
