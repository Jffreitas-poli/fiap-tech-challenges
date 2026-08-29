# fase-3/gitops — Entrega Contínua com ArgoCD

O ArgoCD é instalado no cluster pelo Terraform (`modules/addons`,
`helm_release.argocd`) e passa a ser a **única fonte de verdade** dos deploys
— acabou o `kubectl apply` manual da Fase 2.

## Estrutura

```
root-app.yaml            # Application "app-of-apps"; aplicado pelo Terraform
apps/                    # 1 Application por microsserviço (gerenciadas pela root-app)
  auth.yaml  flag.yaml  targeting.yaml  evaluation.yaml  analytics.yaml
manifests/               # overlays Kustomize que reaproveitam os manifests da Fase 2
  <svc>/kustomization.yaml
```

Cada `manifests/<svc>/kustomization.yaml`:

- referencia os YAMLs de `fase-2/<svc>-service/k8s/` (sem duplicar);
- **omite `secrets.yaml`** de propósito — as credenciais estavam commitadas em
  base64. O Secret é criado a partir do `terraform output` (ver
  `fase-3/infra/README.md`) ou, futuramente, pelo External Secrets Operator;
- expõe `images[].newTag`, que o passo final do CI de cada serviço atualiza
  com a tag publicada no ECR (`vX.Y.Z-<sha>`), disparando o sync automático.

> O ArgoCD é configurado com
> `kustomize.buildOptions: --load-restrictor LoadRestrictionsNone`
> (em `modules/addons`) para permitir que os `kustomization.yaml` acima
> referenciem arquivos fora do seu diretório.

## Gancho de CI (bump de imagem)

Passo final do workflow de build de cada serviço (workflows de aplicação —
a criar numa etapa seguinte; fora do escopo da infra):

```yaml
- name: bump image tag no GitOps
  run: |
    TAG="v${{ github.run_number }}-${GITHUB_SHA::7}"
    yq -i '.images[0].newTag = strenv(TAG)' fase-3/gitops/manifests/auth/kustomization.yaml
    git config user.name  "ci-bot"
    git config user.email "ci-bot@users.noreply.github.com"
    git commit -am "chore(gitops): auth-service ${TAG}"
    git push
  env:
    TAG: ""
```

## Acesso à UI

O `server.ingress` do chart fica desabilitado; o ArgoCD roda em modo
`server.insecure` (TLS termina no ingress-nginx). Para acessar rapidamente:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```
