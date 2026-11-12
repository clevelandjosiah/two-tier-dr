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
  description = "App subnet from the network module"
  type        = string
}

variable "zones" {
  description = "One web VM per zone. Empty in DR, where Site Recovery creates the VMs."
  type        = list(string)
  default     = ["1", "2"]
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v7"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "Public key only. Password login is disabled."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}