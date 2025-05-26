resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = "EC2InstanceRole"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}



