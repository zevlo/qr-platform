variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name. Used as a Name prefix."
  type        = string
  default     = "qr-platform"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "demo"
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_count" {
  description = "Number of worker nodes. Set to 1 for short demos to save cost."
  type        = number
  default     = 2
}

variable "qr_bucket_name" {
  description = "Globally-unique name of the S3 bucket that holds QR code images. Pre-existing; imported."
  type        = string
  default     = "zevlo-qr-platform-codes"
}

variable "tfstate_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform state. Pre-existing; imported."
  type        = string
  default     = "zevlo-qr-platform-tfstate"
}

variable "tfstate_ddb_table" {
  description = "Name of the DynamoDB table used for Terraform state locking. Pre-existing; imported."
  type        = string
  default     = "terraform-locks"
}
