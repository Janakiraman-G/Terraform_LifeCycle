# Data Source

data "aws_ami" "Amazon_Linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get Current AWS region

data "aws_region" "current" {}

# Get availability Zones

data "aws_availability_zones" "available" {
  state = "available"
}


# create_before_destroy
# Use case: Create the EC2 to avoid Zero downtime during updates.

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  tags = merge(
    var.resource_tags,
    {
      Name = var.instance_name
      Demo = "create_before_destroy"
    }
  )

  # Lifecycle Rule: Create new instance before destroying the old one
  # This ensures zero downtime during instance updates (e.g., changing AMI or instance type)
  lifecycle {
    create_before_destroy = true
  }
}

# prevent_destroy
# Use case: Critical S3 bucket that should not be accidentally deleted.

resource "aws_s3_bucket" "critical_data" {
  bucket = "my-critical-production-data-${var.environment}-${data.aws_region.current.name}"

  tags = merge(
    var.resource_tags,
    {
      Name       = "Critical Production Data Bucket"
      Demo       = "prevent_destroy"
      DataType   = "Critical"
      Compliance = "Required"
    }
  )

  # Lifecycle Rule: Prevent accidental deletion of this bucket
  # Terraform will throw an error if you try to destroy this resource
  # To delete: Comment out prevent_destroy first, then run terraform apply
  lifecycle {
    # prevent_destroy = true  # COMMENTED OUT TO ALLOW DESTRUCTION
  }
}

# Enable versioning on the critical bucket
resource "aws_s3_bucket_versioning" "critical_data" {
  bucket = aws_s3_bucket.critical_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ignore Changes
# Use Case: AutoScaling Group Where Capacity is Managed Externally.

# Launch Template for Auto Scaling Group

resource "aws_launch_template" "app_server" {
  name_prefix   = "app-server-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.resource_tags,
      {
        Name = "App Server form ASG"
        Demo = "ignore_changes"
      }
    )
  }

}

# Auto Scaling Group

resource "aws_autoscaling_group" "app_servers" {
  name               = "app-servers-asg"
  min_size           = 1
  max_size           = 3
  desired_capacity   = 2
  health_check_type  = "EC2"
  availability_zones = data.aws_availability_zones.available.names


  launch_template {
    id      = aws_launch_template.app_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "App Server from ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Demo"
    value               = "ignore_changes"
    propagate_at_launch = true
  }


  # Lifecycle Rule: Ignore changes to desired capacity
  # This is useful when the autoScaling policies or external system modify capacity.

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}



# precondition 
# Use case: we're deploying in alloed region


resource "aws_s3_bucket" "precondition_bucket" {
  bucket = "precondition-bucket-${var.environment}-${data.aws_region.current.name}"
  tags = merge(
    var.resource_tags,
    {
      Name = "Pre-condition Bucket"
      Demo = "precondition"
    }
  )

  #Lifecycle Rule: Validate region before creating the bucket

  lifecycle {
    precondition {
      condition     = contains(var.allowed_regions, data.aws_ami.Amazon_Linux_2.id)
      error_message = "This error can only create in allowed regions: ${join(", ", variable.allowed_regions)}. current region: ${data.aws_region.current.name}"
    }
  }
}


# Postcondition
#Use Case: Ensure S3 bucket has required tags after creation

resource "aws_s3_bucket" "postcondition_bucket" {
  bucket = "postcondition-bucket-${var.environment}-${data.aws_region.current.name}"

  tags = merge(
    var.resource_tags,
    {
      Name       = "Post-condition Bucket"
      Demo       = "Postcondition"
      compliance = "SOC2"
    }
  )

  # Lifecycle Rule: Validate tags after creation
  # Use Case: This ensure that orginization's tagging policies

  lifecycle {
    postcondition {
      condition     = contains(keys(self.tags), "Compliance")
      error_message = "The S3 bucket must have a 'Compliance' tag for audit purposes."
    }
    postcondition {
      condition     = contains(keys(self.tags), "Environment")
      error_message = "ERROR: Bucket must have an 'Environment' tag for audit purposes"
    }
  }
}

# replace_triggered_by
# Use Case: replace when EC2 instance when security group changes

# Security Group 

resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Security group for the application"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"

  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH traffic from anywhere"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound traffic to HTTPS from anywhere"

  }

  tags = merge(
    var.resource_tags,
    {
      Name = "App Security Group"
      Demo = "replace_triggered_by"
    }
  )
}

# EC2 instance that get replaced when security group changes

resource "aws_instance" "app_server_with_sg" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = merge(
    var.resource_tags,
    {
      Name = "App Server with SG"
      Demo = "replace_triggered_by"
    }
  )

  # Lifecycle Rule: Replace the instance when the security group changes
  lifecycle {
    replace_triggered_by = [
      aws_security_group.app_sg.id
    ]
  }
}


# Multiple S3 Buckets with create_before_destroy
# Use Case: Manage multiple bucket for a set

resource "aws_s3_bucket" "app_buckets" {
  for_each = var.bucket_name

  bucket = "${each.key}-${var.environment}"

  tags = merge(
    var.resource_tags,
    {
      Name   = each.value
      Demo   = "for_earch_with_lifecycle"
      Bucket = each.key
    }
  )

  # Lifecycle Rule: Create new bucket before destroying the old one
  # Useful when renaming buckets or migrating data

  lifecycle {
    create_before_destroy = true
    ignore_changes = [


    ]
  }

}

# Combain multiple lifecycle rules




