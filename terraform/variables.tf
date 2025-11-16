variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "mlops-starter"
}

variable "env" {
  type    = string
  default = "demo"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "enable_ip_restriction" {
  type        = bool
  default     = false
  description = "Restrict cluster API to your current IP (not recommended for production - use VPN instead)"
}
