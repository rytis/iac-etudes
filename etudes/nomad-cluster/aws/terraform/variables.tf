variable "region" {
  type    = string
  default = "us-east-2"
}

variable "vpc_name" {
  type    = string
  default = "test-nomad"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_azs" {
  type    = list(string)
  default = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "vpc_private_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_public_subnets" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "nomad_server_tags" {
  type = map(string)
  default = {
    nomad-autojoin  = "yes"
    nomad-node-type = "server"
  }
}

variable "nomad_worker_tags" {
  type = map(string)
  default = {
    nomad-node-type = "worker"
  }
}

variable "nomad_cloud_autojoin_string" {
  type    = string
  default = "provider=aws tag_key=nomad-autojoin tag_value=yes"
}

variable "nomad_server_ami_name" {
  type    = string
  default = "nomad-2023-07"
}

variable "nomad_worker_ami_name" {
  type    = string
  default = "nomad-2023-07"
}
