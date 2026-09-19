# General variable definitions for the project

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# S3 bucket

variable "bucket_name" {
    description = "The name of the S3 bucket"
    type        = set(string)
    default     = ["day-7-lifecycle-bucket-1", "day-7-lifecycle-bucket-2"]

}

variable "allowed_regions" {
    description = "A list of allowed AWS regions for resource deployment"
    type        = list(string)
    default     = ["us-east-1", "us-west-2", "eu-west-1"]
}


# EC2 instance

variable "instance_type" {
    description = "The type of EC2 instance to launch"
    type        = string
    default     = "t2.micro"
}

variable "instance_name" {
    description = "The name of the EC2 instance"
    type        = string
    default     = "day-7-lifecycle-instance"
}

# RDS Variables

variable "db_username" {
    description = "The username for the RDS instance"
    type = string
    default = "admin"
    sensitive = true
}

variable "db_password" {
    description = "The password for the RDS instance"
    type = string
    default = "password"
    sensitive = true
}

variable "db_name" {
    description = "Initial database name"
    type = string
    default = "mydatabase"
}

# tags

variable "resource_tags" {
    description = "A map of tags to assign to the resources"
    type        = map(string)
    default = {
        Environment = "dev"
        Team = "DevOps"
        costCenter = "Engineer@2003"
    }
}


