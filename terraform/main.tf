terraform {
  backend "s3" {
    bucket         = "glps-dev-backend-bucket"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "glps_eks_igw"
  }
}

resource "aws_route_table" "rt_custom" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "glps_eks_rt_public"
  }
}

resource "aws_route_table_association" "custom" {
    count = length(var.public_subnet_cidrs)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.rt_custom.id
}

resource "aws_route_table" "rt_main1" {
    vpc_id = aws_vpc.main.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.nat.id
    }
    tags ={
      Name = "glps_eks_rt_private"
    }
}

resource "aws_route_table_association" "main1" {
  count = length(var.private_subnet_cidrs)
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.rt_main1.id
}


resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "glps_eks_eip"
  }
}

resource "aws_nat_gateway" "nat" {
  subnet_id = aws_subnet.public[0].id
  allocation_id = aws_eip.eip.id  

  tags = {
    Name = "glps_eks_nat"
  }
}


resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}




resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )
  }

  depends_on = [aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy]
}

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole",
              "sts:TagSession" ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSComputePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSLoadBalancingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSNetworkingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role = aws_iam_role.eks_cluster.name
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    helm_release.aws_load_balancer_controller
    ]
}

resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

resource "kubernetes_namespace" "webapp1" {
  metadata {
    name = "glps-namespace"
  }
  depends_on = [aws_eks_cluster.eks]
}


resource "kubernetes_deployment" "webapp1" {
  metadata {
    namespace = kubernetes_namespace.webapp1.metadata.name
    name = "glps-webapp1-deployment"
    labels = {
      "webapp1" = "amazon"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        "webapp1" = "amazon"
      }
    }
    template {
      metadata {
        labels = {
          "webapp1" = "amazon"
        }
      }
      spec {
        container {
          name  = "glps-webapp1-container"
          image = var.web_image1
          image_pull_policy = "Always"
          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webapp1" {
  metadata {
    namespace = kubernetes_namespace.webapp1.metadata.name
    name = "glps-webapp1-service"
  }
  spec {
    selector = {
      "webapp1" = "amazon"
    }
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}


resource "kubernetes_deployment" "webapp2" {
  metadata {
    namespace = kubernetes_namespace.webapp1.metadata[0].name
    name = "glps-webapp2-deployment"
    labels = {
      "webapp2" = "Gvrkprasad"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        "webapp2" = "Gvrkprasad"
      }
    }
    template {
      metadata {
        labels = {
          "webapp2" = "Gvrkprasad"
        }
      }
      spec {
        container {
          name  = "glps-webapp2-container"
          image = var.web_image2
          image_pull_policy = "Always"
          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webapp2" {
  metadata {
    namespace = kubernetes_namespace.webapp1.metadata[0].name
    name = "glps-webapp2-service"
  }
  spec {
    selector = {
      "webapp2" = "Gvrkprasad"
    }
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "webapp1" {
  metadata {
    namespace = kubernetes_namespace.webapp1.metadata[0].name
    name = "glps-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/ingress.class"         = "alb"
      "alb.ingress.kubernetes.io/scheme"                = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"           = "ip"
      "alb.ingress.kubernetes.io/group.name"            = "shared-lb"
    }
  }

  spec {
    rule {
      http {
        path {
          path     = "/app1"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.webapp1.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
        path {
          path     = "/app2"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.webapp2.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "aws_iam_role" "alb_sa_iam_role" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.alb_sa_assume_role.json
}

data "aws_iam_policy_document" "alb_sa_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd4e3c1"]  # default EKS thumbprint for ap-south-1
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  depends_on = [ aws_eks_cluster.eks ]
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_sa_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "kubernetes_service_account" "alb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_sa_iam_role.arn
    }
  }
}


resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  depends_on = [aws_iam_openid_connect_provider.oidc_provider,
                kubernetes_namespace.webapp1
  ]

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}