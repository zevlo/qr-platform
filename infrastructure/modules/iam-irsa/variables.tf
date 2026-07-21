variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "account_id" {
  type = string
}

variable "oidc_issuer_url" {
  description = "Issuer URL of the EKS cluster OIDC provider, no scheme (e.g. oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE)."
  type        = string
}

variable "policy_arns" {
  description = "Map of IAM policy ARNs to attach to the role."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
