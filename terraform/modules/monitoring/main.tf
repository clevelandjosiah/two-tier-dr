# ---------- Diagnostic settings: send every log and metric to the workspace ----------

# Asks Azure which log categories each resource supports, so nothing is hardcoded
data "azurerm_monitor_diagnostic_categories" "this" {
  for_each    = var.diagnostic_targets
  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each                   = var.diagnostic_targets
  name                       = "diag-to-law"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.workspace_id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.this[each.key].log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.this[each.key].metrics
    content {
      category = metric.value
    }
  }
}

# ---------- Where alerts go ----------

resource "azurerm_monitor_action_group" "this" {
  name                = "ag-dr-lab"
  resource_group_name = var.resource_group_name
  short_name          = "drlab"
  tags                = var.tags

  email_receiver {
    name                    = "admin"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# ---------- Alert 1: the primary region is down ----------

# Normally the average across both origins is about 50%: primary healthy, DR empty.
# If the primary fails too, it drops toward 0%. Averaging avoids depending on
# per-origin dimension names.
resource "azurerm_monitor_metric_alert" "frontdoor_primary_down" {
  name                = "alert-frontdoor-primary-down"
  resource_group_name = var.resource_group_name
  scopes              = [var.frontdoor_profile_id]
  description         = "Front Door sees no healthy origins. The primary region is likely down."
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Cdn/profiles"
    metric_name      = "OriginHealthPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 25
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# ---------- Alert 2: a web VM failed its health probe ----------

resource "azurerm_monitor_metric_alert" "lb_backend_unhealthy" {
  name                = "alert-lb-backend-unhealthy"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_lb_id]
  description         = "A web VM in West US 3 is failing the load balancer health probe."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "DipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# ---------- Alert 3: Site Recovery replication is critical ----------

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "asr_critical" {
  name                  = "alert-asr-replication-critical"
  resource_group_name   = var.resource_group_name
  location              = var.location
  scopes                = [var.workspace_id]
  description           = "A replicated VM's health is Critical. Failover may not be possible."
  severity              = 1
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  skip_query_validation = true # the table only exists after the vault sends its first logs
  tags                  = var.tags

  criteria {
    query                   = <<-KQL
      AzureDiagnostics
      | where Category == "AzureSiteRecoveryReplicatedItems"
      | where replicationHealth_s == "Critical"
      | summarize count() by name_s
    KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }
}