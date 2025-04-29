terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.11"
    }
  }
}

# AWS provider
provider "aws" {
  region = var.region
   default_tags {
    tags = {
      Environment = "Production"
      Project     = "WebAppOnEKS"
      Owner       = "glps"
    }
  }
}

# 1. Fetch EKS cluster information
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

# 2. Fetch EKS cluster auth informatio
data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

# 3. Kubernetes provider
#provider "kubernetes" {
#  host                   = data.aws_eks_cluster.eks.endpoint
#  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
#  token                  = data.aws_eks_cluster_auth.eks.token
# }

# Add to provider.tf or main.tf
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}



