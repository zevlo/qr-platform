variable "bucket_name" {
  type = string
}

variable "ddb_table" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
