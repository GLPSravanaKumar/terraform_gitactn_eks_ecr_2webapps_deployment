
output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "webapp_hosting_url" {
  value = kubernetes_ingress_v1.webapp1.status[0].load_balancer[0].ingress[0].hostname
}