terraform {
  required_version = ">= 1.1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }

  backend "s3" {
    bucket         = "vader-stg-tf-state-bucket"         
    dynamodb_table = "vader-stg-tf-state-dynamo-db-table"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}


# ----------------- AWS -----------------

provider "aws" {
  # region = var.region
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key
}


##############################################################################################
# BACKEND

resource "aws_s3_bucket" "terraform_state" {
    bucket = "${var.project}-${var.environment_name}-tf-state-bucket"
    force_destroy = true
    versioning {
        enabled = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }
}

resource "aws_dynamodb_table" "terraform_locks" {
    name = "${var.project}-${var.environment_name}-tf-state-dynamo-db-table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}

##############################################################################################
# IAM

# module "iam_account" {
#   source  = "../modules/iam-account"

#   account_alias = "${var.project}-${var.environment_name}-challenge-terraform"

#   minimum_password_length = 37
#   require_numbers         = false
# }


##############################################################################################
# VPC

module "vpc" {
  source = "../modules/vpc"

  name = "${var.project}-${var.environment_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = var.environment_name == "prd" ? true : false
  enable_vpn_gateway = var.environment_name == "prd" ? true : false

  tags = {
    Terraform = "true"
    Environment = "${var.environment_name}"
  }
}

output "public_subnet" {
  value = module.vpc.public_subnets[0]
}


##############################################################################################
# EC2

resource "aws_key_pair" "ssh-keys" {
  key_name   = "${var.project}-${var.environment_name}-ssh-keys"
  public_key = file("./templates/public-key.pub")
}

module "ec2_instance" {
  source  = "../modules/ec2_instance"

  for_each = toset(["1", "2", "3"])

  name = "${var.project}-${var.environment_name}-instance-${each.key}"

  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh-keys.key_name
  monitoring             = true
  vpc_security_group_ids = ["${module.vpc.default_security_group_id}"]
  subnet_id              = "${module.vpc.public_subnets[0]}"

  tags = {
    Terraform   = "true"
    Environment = "${var.environment_name}"
  }
}