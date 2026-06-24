variable "zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "target" {
  type = string
}

resource "cloudflare_dns_record" "minecraft" {
  zone_id = var.zone_id
  name    = var.domain_name
  content = var.target
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

