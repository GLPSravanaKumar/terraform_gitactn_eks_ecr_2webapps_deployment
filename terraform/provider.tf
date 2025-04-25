provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}