variable "ami_name" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "security_groups" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "autojoin_string" {
  type = string
}

variable "ssh_key_name" {
  type = string
}
