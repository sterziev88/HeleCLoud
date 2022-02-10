variable "vpc_cidr" {
  description = "IP Range for the VPC"
  default = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "subnets_azs" {
  description = "AZs in this region to use"
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "ssh_access" {
  default       = "77.85.251.253/32"
  description   = "Give SSH Access into EC2 for selected IP"
}
