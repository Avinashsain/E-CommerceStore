variable "project_name" {
  default = "ecommerce-store"
}
variable "environment" {
  default = "production"
}
variable "aws_region" {
  default = "ap-south-1"
}
variable "instance_type" {
  default = "t3.medium"
}
variable "allowed_ssh_cidr" {
  description = "Your IP — run: curl ifconfig.me"
  default     = "0.0.0.0/0"
}
variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}
variable "jwt_secret" {
  description = "JWT secret for auth"
  sensitive   = true
}
variable "dockerhub_username" {
  description = "DockerHub username"
  default     = "avinashsain65"
}
variable "mongodb_uri_users" {
  description = "MongoDB URI for users DB"
  sensitive   = true
}
variable "mongodb_uri_products" {
  description = "MongoDB URI for products DB"
  sensitive   = true
}
variable "mongodb_uri_carts" {
  description = "MongoDB URI for carts DB"
  sensitive   = true
}
variable "mongodb_uri_orders" {
  description = "MongoDB URI for orders DB"
  sensitive   = true
}
variable "hash_key" {
  default = "LockID"
}