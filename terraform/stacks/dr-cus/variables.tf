variable "location" {
  type    = string
  default = "centralus"
}

variable "address_space" {
  description = "Must not overlap the primary's 10.10.0.0/16, or peering fails"
  type        = string
  default     = "10.20.0.0/16"
}

variable "deploy_bastion" {
  description = "Turn on during drills to log in to failed-over VMs"
  type        = bool
  default     = false
}

variable "sql_admin_login" {
  type    = string
  default = "clean_fg0092.online#EXT#@cleanfg0092.onmicrosoft.com"
}

variable "sql_admin_object_id" {
  type    = string
  default = "20994947-c5b5-4edc-8d76-226dfbdf5657"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "two-tier-dr"
    managed_by = "terraform"
  }
}