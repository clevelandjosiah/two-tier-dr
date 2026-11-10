output "url" {
  value = "https://${azurerm_cdn_frontdoor_endpoint.this.host_name}"
}
output "profile_id" {
  value = azurerm_cdn_frontdoor_profile.this.id
}