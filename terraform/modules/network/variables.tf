variable "name_suffix" {
  description = "Short region name used in resource names, like eus2 or cus"
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "address_space" {
  description = "VNet range, a /16 like 10.10.0.0/16"
  type        = string
}

variable "deploy_bastion" {
  description = "Set false in DR to deploy Bastion only during drills"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}