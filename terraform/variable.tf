variable "region" {
  description = "The AWS region to deploy resources."
  default     = "us-east-1"
}

variable "ssm_parameter_name" {
  description = "The name of the SSM parameter to store and retrieve."
  default     = "example-parameter"
}

variable "codecommit_repo_name" {
  description = "Name of the CodeCommit repository."
  default     = "example-lambda-repo"
}
