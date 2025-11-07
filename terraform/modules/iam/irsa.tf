# terraform/modules/iam/irsa.tf

data "aws_iam_policy_document" "reporting_service_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      identifiers = ["arn:aws:iam::${var.account_id}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/id/${var.oidc_id}"]
      type        = "Federated"
    }
    condition {
      test     = "StringEquals"
      variable = "oidc.eks.${var.aws_region}.amazonaws.com/id/${var.oidc_id}:sub"
      # Update namespace if not prod
      values   = ["system:serviceaccount:nps-${var.environment}:nps-reporting-sa"]
    }
  }
}

resource "aws_iam_role" "reporting_service_irsa" {
  name_prefix        = "${var.environment}-nps-reporting-irsa"
  assume_role_policy = data.aws_iam_policy_document.reporting_service_assume_role_policy.json
}

# Placeholder: Attach a policy allowing access to the S3 reporting bucket
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.reporting_service_irsa.name
  # This should be a least-privilege custom policy ARN
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}