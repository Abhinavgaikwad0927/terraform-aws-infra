module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"

  public_subnet1 = "10.0.1.0/24"
  public_subnet2 = "10.0.2.0/24"

  az1 = "ap-south-1a"
  az2 = "ap-south-1b"
}

module "security-group" {
  source = "./modules/security-group"

  vpc_id = module.vpc.vpc_id
}

module "ec2" {
  source = "./modules/ec2"

  ami_id = var.ami_id

  subnet_id = module.vpc.public_subnet1_id

  security_group_id = module.security-group.sg_id
}

module "alb" {
  source = "./modules/alb"

  vpc_id = module.vpc.vpc_id

  subnet1_id = module.vpc.public_subnet1_id
  subnet2_id = module.vpc.public_subnet2_id

  sg_id = module.security-group.sg_id

  instance_id = module.ec2.instance_id
}

module "s3" {
  source = "./modules/s3"

  bucket_name = var.bucket_name
}
