variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_in_days" {
  type    = number
  default = 365
}

variable "enable_sentinel" {
  type    = bool
  default = true
}

variable "enable_resource_locks" {
  type    = bool
  default = true
}

variable "security_contact_email" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
