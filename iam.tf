resource "aws_iam_policy" "tf_state_access" {
  name        = "tf-state-access"
  description = "Access to Terraform state bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::pii-tf-state"
      },
      {
        Effect = "Allow" #allows team members to read, write, and delete state lock file#
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::pii-tf-state/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "tf_state_attach" {
  for_each = toset(["oxfordgreen95", "lancerkind", "KaanIsmet", "itsmannyvo", "afoshiok"])  

  user       = each.value
  policy_arn = aws_iam_policy.tf_state_access.arn
}