variable "resource_group_name" {
  type = string
}

variable "primary_origin_ip" {
  description = "West US 3 load balancer IP"
  type        = string
}

variable "secondary_origin_ip" {
  description = "Central US load balancer IP"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}