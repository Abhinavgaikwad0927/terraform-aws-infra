resource "aws_instance" "jenkins" {

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = "jenkins"
  subnet_id = var.subnet_id
iam_instance_profile = var.iam_instance_profile
  vpc_security_group_ids = [
    var.security_group_id
  ]
root_block_device {
  volume_size = 50
  volume_type = "gp3"
  encrypted   = true
}
  tags = {
    Name = "Terraform-EC2"
  }
}
