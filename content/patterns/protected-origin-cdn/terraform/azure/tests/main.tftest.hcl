# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name                 = "assets"
  storage_account_name = "stassetstest01"
}

run "front_door_is_premium_for_private_link" {
  command = plan

  assert {
    condition     = azurerm_cdn_frontdoor_profile.this.sku_name == "Premium_AzureFrontDoor"
    error_message = "Private Link hacia el origen solo está en el nivel Premium de Front Door."
  }

  assert {
    condition     = azurerm_cdn_frontdoor_firewall_policy.this.sku_name == "Premium_AzureFrontDoor"
    error_message = "La política WAF usa el mismo SKU que el perfil."
  }
}

run "origin_goes_through_private_link_to_blob" {
  command = plan

  assert {
    condition     = one(azurerm_cdn_frontdoor_origin.blob.private_link).target_type == "blob"
    error_message = "El origen se alcanza por Private Link, con el sub-recurso blob."
  }

  assert {
    condition     = azurerm_cdn_frontdoor_origin.blob.certificate_name_check_enabled == true
    error_message = "El origen verifica el nombre del certificado de la Storage Account."
  }
}

run "storage_has_no_public_network_access" {
  command = plan

  assert {
    condition     = azurerm_storage_account.origin.public_network_access == "Disabled"
    error_message = "La Storage Account de origen no puede tener acceso de red público: solo el private endpoint de Front Door."
  }

  assert {
    condition     = one(azurerm_storage_account.origin.network_rules).default_action == "Deny"
    error_message = "Las reglas de red de la cuenta niegan por defecto."
  }

  assert {
    condition     = azurerm_storage_container.content.container_access_type == "blob"
    error_message = "Front Door lee sin SAS: el contenedor permite lectura anónima de blobs, nunca listado (container)."
  }
}

run "private_origin_group_is_separate_and_routed_over_https" {
  command = plan

  assert {
    condition     = azurerm_cdn_frontdoor_route.this.forwarding_protocol == "HttpsOnly" && azurerm_cdn_frontdoor_route.this.https_redirect_enabled == true
    error_message = "La ruta redirige a HTTPS y reenvía al origen solo por HTTPS."
  }

  assert {
    condition     = azurerm_cdn_frontdoor_route.this.cdn_frontdoor_origin_path == "/content"
    error_message = "El origin path apunta al contenedor."
  }
}

run "no_custom_domain_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_cdn_frontdoor_custom_domain.this) == 0
    error_message = "Sin custom_domain no se crea dominio propio."
  }
}

run "custom_domain_uses_managed_certificate" {
  command = plan

  variables {
    custom_domain = "cdn.example.com"
  }

  assert {
    condition     = one(azurerm_cdn_frontdoor_custom_domain.this[0].tls).certificate_type == "ManagedCertificate"
    error_message = "El dominio propio usa un certificado administrado por Front Door."
  }
}

run "invalid_waf_mode_is_rejected" {
  command = plan

  variables {
    waf_mode = "Off"
  }

  expect_failures = [var.waf_mode]
}
