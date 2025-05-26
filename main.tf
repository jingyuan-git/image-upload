resource "aws_instance" "web" {
  ami                    = "ami-0953476d60561c955"
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "TerraformWeb"
  }
}