resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_ssm_policy" {
  role   = aws_iam_role.lambda_execution_role.id
  policy = data.aws_iam_policy_document.lambda_ssm_permissions.json
}

resource "aws_iam_policy_document" "lambda_ssm_permissions" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.ssm_parameter_name}"]
  }
}

resource "aws_lambda_function" "example_lambda" {
  function_name = "example-lambda-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  filename      = "lambda_function.zip"

  environment {
    variables = {
      SSM_PARAMETER_NAME = var.ssm_parameter_name
    }
  }

  source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_ssm_parameter" "example_parameter" {
  name        = var.ssm_parameter_name
  type        = "String"
  value       = "example-value"
  description = "An example SSM parameter"
}

resource "aws_codecommit_repository" "lambda_repo" {
  repository_name = var.codecommit_repo_name
}

resource "aws_codebuild_project" "build_lambda" {
  name          = "build-lambda-function"
  description   = "Build the Lambda function"
  build_timeout = 5

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/python:3.8"
    type            = "LINUX_CONTAINER"
  }

  source {
    type            = "CODECOMMIT"
    location        = aws_codecommit_repository.lambda_repo.clone_url_http
    buildspec       = "lambda_function/buildspec.yml"
  }

  service_role = aws_iam_role.lambda_execution_role.arn
}

resource "aws_codepipeline" "lambda_pipeline" {
  name     = "lambda-deployment-pipeline"
  role_arn = aws_iam_role.lambda_execution_role.arn

  artifact_store {
    location = "lambda-deployment-artifacts"
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        RepositoryName = aws_codecommit_repository.lambda_repo.repository_name
        BranchName     = "main"
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
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.build_lambda.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name             = "DeployLambda"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "Lambda"
      version          = "1"
      input_artifacts  = ["BuildOutput"]

      configuration = {
        FunctionName = aws_lambda_function.example_lambda.function_name
      }
    }
  }
}
