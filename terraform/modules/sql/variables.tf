variable "name_suffix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  description = "Data subnet from the network module"
  type        = string
}

variable "vnet_id" {
  description = "Linked to the DNS zone so this VNet resolves the private IP"
  type        = string
}

variable "dns_zone_id" {
  type = string
}

variable "dns_zone_name" {
  type = string
}

variable "dns_zone_resource_group" {
  type = string
}

variable "admin_login" {
  description = "Entra ID user or group that administers SQL"
  type        = string
}

variable "admin_object_id" {
  type = string
}

variable "create_database" {
  description = "False in DR. The failover group creates the secondary database."
  type        = bool
  default     = true
}

variable "database_sku" {
  type    = string
  default = "S0"
}

variable "tags" {
  type    = map(string)
  default = {}
}

