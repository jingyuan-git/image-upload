# resource "aws_iam_role" "ec2_role" {
#   name = "EC2InstanceRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

data "aws_iam_role" "existing_ec2_role" {
  name = "EC2InstanceRole"
}


resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = data.aws_iam_role.existing_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2InstanceProfile"
  role = data.aws_iam_role.existing_ec2_role.name
}