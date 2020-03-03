provider "aws" {
  region = "${var.region}"
}

data "aws_ssm_parameter" "oauth" {
  name = "GithubOAuthToken"
}

locals {
  project_name = "${var.environment}-spa-codepipeline-demo"
}

resource "aws_s3_bucket" "spa_codepipeline_demo" {
  bucket = local.project_name
  acl    = "public-read"
  force_destroy = true
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
              "s3:GetObject"
          ],
          "Resource": [
              "arn:aws:s3:::${var.environment}-spa-codepipeline-demo/*"
          ]
      },
      {
          "Sid": "CodePipeline",
          "Effect": "Allow",
          "Principal": {
          "AWS": "${aws_iam_role.codepipeline_role.arn}"
      },
          "Action": "s3:*",
          "Resource": "arn:aws:s3:::${var.environment}-spa-codepipeline-demo/*"
      }
  ]
}
POLICY

  website {
    index_document = "index.html"
  }
}


resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.environment}-codepipeline-bucket"
  acl    = "private"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.environment}-codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.environment}-codepipeline_policy"
  role = "${aws_iam_role.codepipeline_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObjectAcl",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.spa_codepipeline_demo.arn}",
        "${aws_s3_bucket.spa_codepipeline_demo.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    }
  ]
}
EOF
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.environment}-spa-codepipeline-demo-pipeline"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_bucket.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner  =  "${var.repo_owner}"
        Repo   = "${var.repo_name}"
        Branch = "${var.repo_branch}"
        OAuthToken = "${data.aws_ssm_parameter.oauth.value}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = local.project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = "${aws_s3_bucket.spa_codepipeline_demo.bucket}"
        Extract = "true"
      }
    }
  }
}

resource "aws_codebuild_project" "spa_codebuild" {
  name          = local.project_name
  description   = "test_codebuild_project"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codepipeline_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "log-group"
      stream_name = "log-stream"
    }

    s3_logs {
      status = "ENABLED"
      location = "${aws_s3_bucket.codepipeline_bucket.id}/build-log"
    }
  }

  source {
    buildspec = "pipeline/buildspec-build.yml"
    type = "CODEPIPELINE"
  }

  tags = {
    Environment = "Demo"
  }
}