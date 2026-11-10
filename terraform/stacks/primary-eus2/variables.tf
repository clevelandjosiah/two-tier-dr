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
  default     = true
}

variable "tags" {
  type = map(string)
  default = {
    project    = "two-tier-dr"
    managed_by = "terraform"
  }
}

variable "sql_admin_login" {
  type    = string
  default = "clean_fg0092.online#EXT#@cleanfg0092.onmicrosoft.com"
}

variable "sql_admin_object_id" {
  type    = string
  default = "20994947-c5b5-4edc-8d76-226dfbdf5657"
}