terraform {
  backend "s3" {
    bucket         = "glps-dev-backend-bucket"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}