
variable "name"               { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "alb_tg_arn"         { type = string }
variable "instance_type"      { type = string }
variable "ssh_public_key"     { type = string }
variable "user_data"          { type = string }
variable "ssh_public_key" {
  type = string
}