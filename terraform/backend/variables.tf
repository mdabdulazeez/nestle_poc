variable "aws_region" {
  description = "AWS region for the backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = "Prefix for the S3 bucket name that will store Terraform state"
  type        = string
  default     = "nestle-poc-terraform-state"
}

variable "lock_table_prefix" {
  description = "Prefix for the DynamoDB table name that will handle Terraform state locking"
  type        = string
  default     = "nestle-poc-terraform-locks"
} 