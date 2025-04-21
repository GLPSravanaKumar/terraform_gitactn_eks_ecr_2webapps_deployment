variable "region" {
  default = "ap-south-1"
}

variable "web_image" {
  description = "Docker image for the static web app"
}

variable "cluster_name" {
  default = "glps-demo-eks-cluster"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.5.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.3.0/24", "10.0.4.0/24", "10.0.7.0/24"]
}
