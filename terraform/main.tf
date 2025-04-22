terraform {
  backend "s3" {
    bucket         = "glps-dev-backend-bucket"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
  }
}

resource "aws_internet_gateway" "igw" {
 
  tags = {
    Name = "glps_eks_igw"
  }
}

resource "aws_internet_gateway_attachment" "igw_attac" {
   vpc_id = aws_vpc.main.id
   internet_gateway_id = aws_internet_gateway.igw.id
   lifecycle {
    prevent_destroy = true
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

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.cluster_name}-public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.cluster_name}-private-${count.index}"
  }
}

data "aws_availability_zones" "available" {}


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
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy]
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

resource "kubernetes_namespace" "webapps" {
  metadata {
    name = "webapps"
  }
}


resource "kubernetes_deployment" "static_web" {
  metadata {
    name = "static-web-deployment"
    labels = {
      app = "static-web"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "static-web"
      }
    }
    template {
      metadata {
        labels = {
          app = "static-web"
        }
      }
      spec {
        container {
          name  = "static-web-container"
          image = var.web_image
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "static_web_service" {
  metadata {
    name = "static-web-service"
  }
  spec {
    selector = {
      app = "static-web"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
