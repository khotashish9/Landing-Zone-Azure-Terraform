variable "plans" {
  type = map(object({
    subplan = optional(string)
  }))
}

variable "security_contact_email" {
  type = string
}
