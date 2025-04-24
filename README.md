Here's a complete, step-by-step guide to create an AWS EKS (Elastic Kubernetes Service) cluster using Terraform — including all the necessary Terraform files, configurations, and instructions.

✅ Prerequisites
Before you begin:

AWS account

IAM user with sufficient EKS, VPC, EC2, IAM permissions

Terraform installed (>= 1.0)

kubectl installed

awscli installed and configured (aws configure)

You want to host a static HTML/CSS/JS web application on an AWS EKS cluster using Terraform.

✅ Steps Overview
📦 Create a Docker image of your static website

🐳 Push the image to ECR (Elastic Container Registry)

☸️ Deploy the app to EKS (as a Pod + Service)

🌐 Expose it via LoadBalancer or Ingress


