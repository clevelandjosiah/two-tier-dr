variable "location" {
  description = "Global resources still need a home region. Central US survives a primary outage."
  type        = string
  default     = "centralus"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "two-tier-dr"
    managed_by = "terraform"
  }
}