resource "aws_instance" "web" {
  ami                  = "ami-xxxxxx"
  instance_type        = var.instance_type
  key_name             = var.key_name
  subnet_id            = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = { Name = "Image-Upload-Web" }
}