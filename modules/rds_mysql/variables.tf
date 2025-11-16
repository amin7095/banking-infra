
variable "name"               { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "engine_version"     { type = string default = "8.0.35" }
variable "instance_class"     { type = string default = "db.t3.micro" }
variable "allocated_storage"  { type = number default = 20 }
variable "multi_az"           { type = bool   default = false }
