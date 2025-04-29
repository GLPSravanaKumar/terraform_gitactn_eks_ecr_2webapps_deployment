data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.cluster_name}/vpc"
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
    "kubernetes.io/role/elb"                    = "true"
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
    "kubernetes.io/role/internal-elb"           = "true"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
 
  tags = {
    Name = "${var.cluster_name}/igw"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}/eip"
  }
}

resource "aws_nat_gateway" "nat" {
  subnet_id = aws_subnet.public[0].id
  allocation_id = aws_eip.eip.id  

  tags = {
    Name = "${var.cluster_name}/nat"
  }
  depends_on = [ aws_eip.eip ]
}

resource "aws_route_table" "custom" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.cluster_name}/public_rt"
  }
}

resource "aws_route_table_association" "custom" {
    count = length(var.public_subnet_cidrs)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.custom.id
}

resource "aws_route_table" "main" {
    vpc_id = aws_vpc.main.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.nat.id
    }
    tags ={
      Name = "${var.cluster_name}/private_rt"
    }
}

resource "aws_route_table_association" "main" {
  count = length(var.private_subnet_cidrs)
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.main.id
}

#IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = [
          "sts:AssumeRole",
          "sts:TagSession"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "EKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "EKSVPCResourceController" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeGroupRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
      )
    }  

    depends_on = [aws_iam_role_policy_attachment.EKSClusterPolicy]

    tags = {
      Name = "${var.cluster_name}/cluster"
    }
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_readonly
    ]
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "glps-namespace"
  }
  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.node_group
    ]
}


resource "kubernetes_deployment" "webapp1" {
  metadata {
    namespace = kubernetes_namespace.ns.metadata[0].name
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
    namespace = kubernetes_namespace.ns.metadata[0].name
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
    namespace = kubernetes_namespace.ns.metadata[0].name
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
    namespace = kubernetes_namespace.ns.metadata[0].name
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
    namespace = kubernetes_namespace.ns.metadata[0].name
    name = "glps-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/ingress.class"         = "alb"
      "alb.ingress.kubernetes.io/scheme"                = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"           = "ip"
      "alb.ingress.kubernetes.io/group.name"            = "shared-lb"
      "alb.ingress.kubernetes.io/listen-ports"          = "[{\"HTTP\": 80}]"
    }
  }

  spec {
    ingress_class_name = "alb"
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

