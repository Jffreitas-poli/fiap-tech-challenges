# modulo `iam_oidc_github` — NAO usado no AWS Academy

Este modulo cria o **OIDC Identity Provider do GitHub** e uma **IAM Role**
que os workflows do GitHub Actions assumem via `sts:AssumeRoleWithWebIdentity`
(autenticacao sem chaves de longa duracao).

**Ele nao e instanciado em `envs/lab/`** porque o AWS Academy / Vocareum
bloqueia `iam:CreateOpenIDConnectProvider` e `iam:CreateRole`. No lab, os
workflows autenticam com as chaves estaticas da sessao (`AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) guardadas como GitHub Secrets.

## Uso em conta AWS real

```hcl
module "gha_oidc" {
  source           = "../../modules/iam_oidc_github"
  github_org       = "NyEstevo"
  github_repo      = "fiap-tech-challenges"
  allowed_branches = ["main"]
  role_name        = "gha-toggle-master-infra"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    # ... o minimo necessario para o plan/apply
  ]
}
```

Nos workflows, trocar o bloco de chaves estaticas por:

```yaml
permissions:
  id-token: write
  contents: read
# ...
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_GHA_ROLE_ARN }}   # module.gha_oidc.role_arn
    aws-region: us-east-1
```
