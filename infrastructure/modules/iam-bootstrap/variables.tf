variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_owner_id" {
  type = string
}

variable "github_repo_id" {
  type = string
}

variable "role_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
