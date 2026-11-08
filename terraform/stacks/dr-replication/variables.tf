variable "state_storage_account" {
  description = "Same account as in backend.tf"
  type        = string
  default     = "sttfstate19323"
}

variable "primary_location" {
  type    = string
  default = "eastus2"
}

variable "dr_location" {
  type    = string
  default = "centralus"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "two-tier-dr"
    managed_by = "terraform"
  }
}