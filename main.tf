resource "aws_iam_role" "role" {
    name                 = "tf-pipeline-role"
    assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codepipeline.amazonaws.com", "codebuild.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "policy" { 
    name = "tf-pipeline-policy"
    role = aws_iam_role.role.id

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:ListAllMyBuckets",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetObjectAcl",
                "s3:GetBucketVersioning",
                "s3:PutObjectAcl",
                "s3:PutObject"
            ],
            "Resource": [
                "${aws_s3_bucket.bucket.arn}",
                "${aws_s3_bucket.bucket.arn}/*",
                "${aws_s3_bucket.cb_bucket.arn}",
                "${aws_s3_bucket.cb_bucket.arn}/*"                
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codestar-connections:UseConnection"
            ],
            "Resource": "${aws_codestarconnections_connection.tf-pipeline.arn}"
        },
        {
            "Effect": "Allow",
            "NotAction": [
                "iam:*",
                "organizations:*",
                "account:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole",
                "iam:DeleteServiceLinkedRole",
                "iam:ListRoles",
                "organizations:DescribeOrganization",
                "account:ListRegions"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

#################################################################################
#
#                          AWS S3 BUCKET BUILDOUT
#
#################################################################################

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-pipeline"
}

resource "aws_s3_bucket_acl" "acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "cb_bucket" {
  bucket = "tf-pipeline-cb"
}

resource "aws_s3_bucket_acl" "cb_acl" {
  bucket = aws_s3_bucket.cb_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "cb_versioning" {
  bucket = aws_s3_bucket.cb_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}



#################################################################################
#
#                          AWS CODE PIPELINE BUILDOUT
#
#################################################################################

resource "aws_codepipeline" "codepipeline"{
  name = "terraform-pipeline"
  role_arn = aws_iam_role.role.arn

  artifact_store {
    location = aws_s3_bucket.bucket.bucket
    type     = "S3"
  }

  stage {
      name = "Source"

      action {
        name             = "Source"
        category         = "Source"
        owner            = "AWS"
        provider         = "CodeStarSourceConnection"
        version          = "1"
        output_artifacts = ["source_output"]

        configuration = {
          ConnectionArn    = aws_codestarconnections_connection.tf-pipeline.arn
          FullRepositoryId = var.repositoryid
          BranchName       = "main"
        }
      }
    }

  stage {

    action {
      name             = "Terraform_Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["tfplan_output"]
      version          = "1"

      configuration    = {
        ProjectName    = aws_codebuild_project.terraform_plan.name
      }
    }

    name = "Terraform_Plan"
    action {
      name             = "Terraform_Plan_Manual_Approval"
      category         = "Approval"
      owner            = "AWS"
      provider         = "Manual"
      version          = "1"
    }

  }

  stage {
    name = "Terraform_Apply"
    action {
      name             = "Terraform_Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration    = {
        ProjectName    = aws_codebuild_project.terraform_apply.name
      }
    }
  }
  
}

resource "aws_codestarconnections_connection" "tf-pipeline" {
  name          = "tf-pipeline-github"
  provider_type = "GitHub"
}

resource "aws_codebuild_project" "terraform_plan" {
  name         = "Terraform-Plan"
  service_role = aws_iam_role.role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "TF_COMMAND_P"
      value = "plan"
    }
  }
  cache {
    type     = "S3"
    location = "${aws_s3_bucket.cb_bucket.bucket}/terraform_plan/cache"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "terraform_plan.yml"
  }
}


resource "aws_codebuild_project" "terraform_apply" {
  name         = "Terraform-Apply"
  service_role = aws_iam_role.role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "TF_COMMAND_A"
      value = "apply"
    }
  }
  cache {
    type     = "S3"
    location = "${aws_s3_bucket.cb_bucket.bucket}/terraform_apply/cache"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "terraform_apply.yml"
  }
}


