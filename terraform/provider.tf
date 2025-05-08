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
  name = aws_eks_cluster.eks.name
}

# 2. Fetch EKS cluster auth informatio
data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

data "tls_certificate" "oidc_thumbprint" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}


# Add to provider.tf or main.tf
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}


