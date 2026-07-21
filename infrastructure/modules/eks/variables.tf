variable "name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_instance_type" {
  type = string
}

variable "node_count" {
  type = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
