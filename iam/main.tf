resource "aws_iam_role_policy" "allow_attach_policy" {
  name = "AllowAttachPolicyToEC2InstanceRole"
  role = "EC2InstanceRole"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy"]
        Resource = "arn:aws:iam::649490358042:role/EC2InstanceRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = "EC2InstanceRole"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}



