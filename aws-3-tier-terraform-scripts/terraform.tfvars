
aws_region = "us-east-1"

vpc_cidr     = "10.0.0.0/16"
subnet1_cidr = "10.0.1.0/24"
subnet2_cidr = "10.0.2.0/24"
subnet3_cidr = "10.0.3.0/24"
subnet4_cidr = "10.0.4.0/24"
subnet5_cidr = "10.0.5.0/24"
subnet6_cidr = "10.0.6.0/24"

public_subnet1_az  = "us-east-1a"
public_subnet2_az  = "us-east-1b"
private_subnet1_az = "us-east-1b"
private_subnet2_az = "us-east-1c"
private_subnet3_az = "us-east-1b"
private_subnet4_az = "us-east-1c"

# Consider restricting SSH to your IP/CIDR
ssh_allowed_cidrs = ["0.0.0.0/0"]

ami_id            = "ami-07ff62358b87c7116"
web_instance_type = "t3.small"
key_name          = "mykp"
ecomm_user_data   = "data1.sh"
food_user_data    = "data2.sh"

db_allocated_storage   = 10
db_engine              = "mysql"
db_engine_version      = "8.0.44"
db_instance_class      = "db.t3.small"
db_multi_az            = true
db_username            = "admin"
db_password            = "password" # Replace with a secure secret in production
db_skip_final_snapshot = true
