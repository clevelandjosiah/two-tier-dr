variable "name_suffix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vm_ids" {
  description = "VMs to protect, from the compute module's vm_ids output"
  type        = map(string)
}

variable "backup_time" {
  description = "Daily backup time, in Eastern time"
  type        = string
  default     = "23:00"
}

variable "retention_days" {
  description = "How many daily backups to keep. Azure's minimum is 7."
  type        = number
  default     = 7
}

variable "soft_delete_enabled" {
  description = "True in production. False here so the lab can be destroyed cleanly."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}