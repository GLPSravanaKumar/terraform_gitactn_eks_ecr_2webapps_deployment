output "web_url" {
  value = kubernetes_service.static_web_service.status[0].load_balancer[0].ingress[0].hostname
}

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "kubeconfig" {
  value = aws_eks_cluster.eks.kubeconfig[0].raw_kubeconfig
  description = "Use this to configure kubectl access"
}
