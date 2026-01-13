
# General
variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

# VPC & Subnets
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR, e.g., 10.0.0.0/16."
  }
}

variable "subnet1_cidr" {
  description = "CIDR block for public-subnet1"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.subnet1_cidr))
    error_message = "subnet1_cidr must be a valid CIDR, e.g., 10.0.1.0/24."
  }
}

variable "subnet2_cidr" {
  description = "CIDR block for public-subnet2"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.subnet2_cidr))
    error_message = "subnet2_cidr must be a valid CIDR, e.g., 10.0.2.0/24."
  }
}

variable "subnet3_cidr" {
  description = "CIDR block for private-subnet1"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.subnet3_cidr))
    error_message = "subnet3_cidr must be a valid CIDR, e.g., 10.0.3.0/24."
  }
}

variable "subnet4_cidr" {
  description = "CIDR block for private-subnet2"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.subnet4_cidr))
    error_message = "subnet4_cidr must be a valid CIDR, e.g., 10.0.4.0/24."
  }
}

variable "subnet5_cidr" {
  description = "CIDR block for private-subnet3"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.subnet5_cidr))
    error_message = "subnet5_cidr must be a valid CIDR, e.g., 10.0.5.0/24."
  }
}

variable "subnet6_cidr" {
  description = "CIDR block for private-subnet4"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.subnet6_cidr))
    error_message = "subnet6_cidr must be a valid CIDR, e.g., 10.0.6.0/24."
  }
}

# AZs
variable "public_subnet1_az" {
  description = "AZ for public-subnet1"
  type        = string
  default     = "us-east-1a"
}

variable "public_subnet2_az" {
  description = "AZ for public-subnet2"
  type        = string
  default     = "us-east-1b"
}

variable "private_subnet1_az" {
  description = "AZ for private-subnet1"
  type        = string
  default     = "us-east-1b"
}

variable "private_subnet2_az" {
  description = "AZ for private-subnet2"
  type        = string
  default     = "us-east-1c"
}

variable "private_subnet3_az" {
  description = "AZ for private-subnet3"
  type        = string
  default     = "us-east-1b"
}

variable "private_subnet4_az" {
  description = "AZ for private-subnet4"
  type        = string
  default     = "us-east-1c"
}

variable "public_subnets_map_public_ip" {
  description = "Whether to auto-assign public IPs on launch in public subnets"
  type        = bool
  default     = true
}

# Security
variable "ssh_allowed_cidrs" {
  description = "List of CIDR blocks allowed to SSH into web instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# EC2
variable "ami_id" {
  description = "AMI ID for web instances"
  type        = string
  default     = "ami-07ff62358b87c7116"
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,}$", var.ami_id))
    error_message = "ami_id must look like ami-xxxxxxxx."
  }
}

variable "web_instance_type" {
  description = "Instance type for web instances"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "mykp"
}

variable "ecomm_user_data" {
  description = "Path to user data script for EC2-1"
  type        = string
  default     = "data1.sh"
}

variable "food_user_data" {
  description = "Path to user data script for EC2-2"
  type        = string
  default     = "data2.sh"
}

# RDS
variable "db_allocated_storage" {
  description = "Allocated storage (GB) for RDS"
  type        = number
  default     = 10
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0.35"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on RDS deletion (not recommended for production)"
  type        = bool
  default     = true
}
