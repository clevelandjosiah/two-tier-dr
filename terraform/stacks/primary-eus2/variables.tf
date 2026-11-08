variable "location" {
  type    = string
  default = "eastus2"
}

variable "address_space" {
  type    = string
  default = "10.10.0.0/16"
}

variable "deploy_bastion" {
  description = "Bastion bills hourly, so leave it off until you need to log in"
  type        = bool
  default     = false
}

variable "tags" {
  type = map(string)
  default = {
    project    = "two-tier-dr"
    managed_by = "terraform"
  }
}