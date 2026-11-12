resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "afd-two-tier-dr"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

# The one address users always go to
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "two-tier-dr"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                     = "web"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  # How Front Door decides a region is down
  health_probe {
    protocol            = "Http"
    path                = "/"
    request_type        = "HEAD"
    interval_in_seconds = 30
  }

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }
}

resource "azurerm_cdn_frontdoor_origin" "primary" {
  name                           = "primary-wus3"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                        = true
  host_name                      = var.primary_origin_ip
  origin_host_header             = var.primary_origin_ip
  http_port                      = 80
  https_port                     = 443
  priority                       = 1 # preferred while healthy
  weight                         = 1000
  certificate_name_check_enabled = false
}

resource "azurerm_cdn_frontdoor_origin" "secondary" {
  name                           = "secondary-cus"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                        = true
  host_name                      = var.secondary_origin_ip
  origin_host_header             = var.secondary_origin_ip
  http_port                      = 80
  https_port                     = 443
  priority                       = 2 # used only when primary fails its health checks
  weight                         = 1000
  certificate_name_check_enabled = false
}

resource "azurerm_cdn_frontdoor_route" "web" {
  name                          = "web"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.primary.id, azurerm_cdn_frontdoor_origin.secondary.id]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "HttpOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
}