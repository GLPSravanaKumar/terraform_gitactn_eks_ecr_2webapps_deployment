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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# AWS provider
provider "aws" {
  region = var.region
}

# 1. Fetch EKS cluster information
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
  depends_on = [ aws_eks_cluster.eks ]
}

# 2. Fetch EKS cluster auth informatio
data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
  depends_on = [ aws_eks_cluster.eks ]
}

# 3. Kubernetes provider
#provider "kubernetes" {
#  host                   = data.aws_eks_cluster.eks.endpoint
#  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
#  token                  = data.aws_eks_cluster_auth.eks.token
# }

# Add to provider.tf or main.tf
provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.eks.name,
      "--region",
      var.region
    ]
  }
}

# 4. Helm provider
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  } 
}