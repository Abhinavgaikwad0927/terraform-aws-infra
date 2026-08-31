resource "aws_instance" "jenkins" {

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = "jenkins"
  subnet_id = var.subnet_id
iam_instance_profile = var.iam_instance_profile
  vpc_security_group_ids = [
    var.security_group_id
  ]

  tags = {
    Name = "Terraform-EC2"
  }
}
