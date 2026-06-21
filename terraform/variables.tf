variable "project_name" {
  default = "ecommerce-store"
}
variable "environment" {
  default = "production"
}
variable "aws_region" {
  default = "us-east-1"
}
variable "instance_type" {
  default = "t3.small"
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
variable "hash_key" {
  description = "DynamoDB hash key for Terraform state locking"
  type        = string
  default     = "LockID"
}
