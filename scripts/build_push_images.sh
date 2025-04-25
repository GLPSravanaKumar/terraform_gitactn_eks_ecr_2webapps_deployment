#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-south-1"
REPO_NAME1="glps-webapp1-repo"
REPO_NAME2="glps-webapp2-repo"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Create repos if not exist
aws ecr describe-repositories --repository-names $REPO_NAME1 || aws ecr create-repository --repository-name $REPO_NAME1
aws ecr describe-repositories --repository-names $REPO_NAME2 || aws ecr create-repository --repository-name $REPO_NAME2

# Build and Push webapp1 image
docker build -t $REPO_NAME1 ./webapp1
docker tag $REPO_NAME1:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME1:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME1:latest

# Build and Push webapp2 image
docker build -t $REPO_NAME2 ./webapp2
docker tag $REPO_NAME2:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME2:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME2:latest
