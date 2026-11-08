variable "location" {
  description = "DR region, where the vault and failed-over VMs live"
  type        = string
}

variable "resource_group_name" {
  description = "DR resource group"
  type        = string
}

variable "source_location" {
  type = string
}

variable "source_resource_group_name" {
  description = "Primary resource group, where the cache account lives"
  type        = string
}

variable "source_vnet_id" {
  type = string
}

variable "target_vnet_id" {
  type = string
}

variable "target_resource_group_id" {
  type = string
}

variable "target_subnet_name" {
  type    = string
  default = "snet-app"
}

variable "target_backend_pool_id" {
  description = "DR load balancer pool that failed-over VMs join"
  type        = string
}

variable "vms" {
  description = "Primary VMs to replicate, keyed by zone"
  type = map(object({
    vm_id      = string
    nic_id     = string
    os_disk_id = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}