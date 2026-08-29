########################################################################
# modulo iam_oidc_github  (referencia -- NAO aplicavel no AWS Academy)
# OIDC provider do GitHub + IAM Role assumida pelos workflows via
# sts:AssumeRoleWithWebIdentity.
########################################################################

locals {
  oidc_url = "token.actions.githubusercontent.com"

  branch_subs = [
    for b in var.allowed_branches :
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${b}"
  ]
  pr_subs = var.allow_pull_requests ? [
    "repo:${var.github_org}/${var.github_repo}:pull_request"
  ] : []

  allowed_subs = concat(local.branch_subs, local.pr_subs)
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://${local.oidc_url}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://${local.oidc_url}"
}

locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      values   = local.allowed_subs
    }
  }
}

resource "aws_iam_role" "gha" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "gha" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.gha.name
  policy_arn = each.value
}
