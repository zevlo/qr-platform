variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "data" {
  description = "Key/value pairs to store as JSON in the secret."
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
