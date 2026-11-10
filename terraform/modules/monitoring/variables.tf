variable "resource_group_name" {
  description = "Where the action group and alerts live"
  type        = string
}

variable "location" {
  type = string
}

variable "workspace_id" {
  description = "Log Analytics workspace that receives all logs"
  type        = string
}

variable "diagnostic_targets" {
  description = "Resources that send logs and metrics to the workspace, keyed by a short name"
  type        = map(string)
}

variable "frontdoor_profile_id" {
  type = string
}

variable "primary_lb_id" {
  type = string
}

variable "alert_email" {
  description = "Where alerts are sent. Set through TF_VAR_alert_email so it stays out of the repo."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}