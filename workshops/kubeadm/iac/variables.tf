# Add your variable declarations here

variable "subscription_id" {
  description = "value of the subscription id"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "The admin username for the virtual machine"
  type        = string
  sensitive   = true
}
variable "admin_password" {
  description = "The admin password for the virtual machine"
  type        = string
  sensitive   = true
}
variable "root_ssh_public_key" {
  description = "The public key for SSH access"
  type        = string

}
variable "owner" {
  description = "The owner of the resources"
  type        = string
}