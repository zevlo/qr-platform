variable "region" {
  type = string
}

variable "repos" {
  type    = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
