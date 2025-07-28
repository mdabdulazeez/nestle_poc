
# Output the backend configuration
output "backend_config" {
  description = "Backend configuration for other Terraform configurations"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = true
  }
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_initialization_commands" {
  description = "Commands to initialize Terraform with this backend"
  value = <<-EOT
    
    To initialize your main Terraform environment with this backend, run:
    
    cd terraform/environments/dev
    terraform init \
      -backend-config="bucket=${aws_s3_bucket.terraform_state.bucket}" \
      -backend-config="key=dev/terraform.tfstate" \
      -backend-config="region=${var.aws_region}" \
      -backend-config="dynamodb_table=${aws_dynamodb_table.terraform_locks.name}" \
      -backend-config="encrypt=true"
    
    Or create a backend.hcl file:
    cat > backend.hcl << EOF
    bucket         = "${aws_s3_bucket.terraform_state.bucket}"
    key            = "dev/terraform.tfstate"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    encrypt        = true
    EOF
    
    Then run: terraform init -backend-config=backend.hcl
    
  EOT
} 