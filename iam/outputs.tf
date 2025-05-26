# output "instance_profile_name" {
#   value = "EC2InstanceProfile"
# }

output "iam_instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}