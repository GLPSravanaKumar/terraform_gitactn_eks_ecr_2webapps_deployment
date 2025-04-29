variable "region" {
  default = "ap-south-1"
}

variable "web_image1" {
  description = "Docker image for the static web app1"
  type = string
}
variable "web_image2" {
  description = "Docker image for the static web app2"
  type = string
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

variable "vpc_id" {
  default = "vpc-01e81871f95584ed2"
}