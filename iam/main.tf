
# resource "aws_iam_role_policy_attachment" "ec2_full_access" {
#   role       = "EC2InstanceRole"
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
# }

# resource "aws_iam_instance_profile" "this" {
#   name = "EC2InstanceProfile"
#   role = aws_iam_role.this.name
# }

