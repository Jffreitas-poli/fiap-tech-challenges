# BASELINE — retrato do que o ArgoCD sincroniza HOJE

Este arquivo nao propoe nada. E o registro do **estado atual verificavel** da
fase-3 em execucao: o que nao pode mudar sem intencao declarada.

**Como foi levantado:** o ArgoCD sincroniza a branch `lab`
(`targetRevision: lab` nas 7 Applications e na root-app). No momento do
levantamento, `git diff origin/lab HEAD -- fase-2 fase-3/gitops .github` saiu
**vazio** — logo o working tree e literalmente o que esta no ar, e cada valor
abaixo pode ser reconferido com `git show origin/lab:<arquivo>`.

Convencoes usadas nas tabelas:

- `OLD` = `047719652987.dkr.ecr.us-east-2.amazonaws.com/tech-challenge`
  (conta/regiao da fase-2; **nunca e puxada** — ver "Registry efetivo")
- `NEW` = `361075236043.dkr.ecr.us-east-1.amazonaws.com/tech-challenge`
  (conta/regiao da fase-3, lab)

---

## Visao geral

| serviço | overlay que o ArgoCD sincroniza | Application | namespace |
|---|---|---|---|
| auth | `fase-3/gitops/manifests/auth` | `auth-service` | `toggle` |
| flag | `fase-3/gitops/manifests/flag` | `flag-service` | `toggle` |
| targeting | `fase-3/gitops/manifests/targeting` | `targeting-service` | `toggle` |
| evaluation | `fase-3/gitops/manifests/evaluation` | `evaluation-service` | `toggle` |
| analytics | `fase-3/gitops/manifests/analytics` | `analytics-service` | `toggle` |
| — | `fase-3/gitops/manifests/platform` | `platform` | `external-secrets` |
| — | `fase-3/gitops/manifests/ingress` | `ingress` | `toggle` |

**Sao 7 Applications, nao 5.** `platform` e `ingress` nao sao servicos, mas sao
Applications vivas com `prune: true`. Qualquer refactor que gere Applications
com nomes diferentes destes deixa a original orfa; deletar orfa com prune ativo
derruba pod.

Todas as 7 tem `project: default`, `repoURL` `https://github.com/NyEstevo/fiap-tech-challenges.git`,
`targetRevision: lab`, `syncPolicy.automated{prune: true, selfHeal: true}`,
`syncOptions: [CreateNamespace=true, ServerSideApply=true]` e o finalizer
`resources-finalizer.argocd.argoproj.io`. Somente `platform` tem
`argocd.argoproj.io/sync-wave: "-1"` na Application.

Geradas pela root-app `toggle-master-root`
([fase-3/gitops/root-app.yaml](gitops/root-app.yaml)), que aponta para
`fase-3/gitops/apps` com `directory.recurse: true` e e aplicada pelo Terraform
(`null_resource.root_app`, trigger `filesha256(local.gitops_root_app_path)`).

---

## Imagens: `images[].name`, `newName`, `newTag`

| serviço | `images[].name` (chave de match) | `newName` | `newTag` |
|---|---|---|---|
| auth | `OLD/auth-image` | `NEW/auth-image` | `5e35bd5dce31f64b09f460cbdd95a575e9b07876` |
| auth (2ª entrada) | `NEW/auth-migrate-image` | `NEW/auth-migrate-image` | `5e35bd5dce31f64b09f460cbdd95a575e9b07876` |
| flag | `OLD/flag-image` | `NEW/flag-image` | `0ec35360d76036cdcaa1d4c5247556be65b29693` |
| targeting | `OLD/targeting-image` | `NEW/targeting-image` | `0ec35360d76036cdcaa1d4c5247556be65b29693` |
| evaluation | `OLD/evaluation-image` | `NEW/evaluation-image` | `5e35bd5dce31f64b09f460cbdd95a575e9b07876` |
| analytics | `OLD/analytics-image` | `NEW/analytics-image` | `5e35bd5dce31f64b09f460cbdd95a575e9b07876` |

Auth e o unico com **duas** entradas em `images[]`. Na segunda, `name` e igual a
`newName` — a imagem de migration ja nasceu apontando para a conta nova, entao a
entrada existe so para o CI ter onde escrever `newTag`.

### Registry e regiao efetivos apos o render

**Todos os 5 renderizam para `361075236043.dkr.ecr.us-east-1.amazonaws.com`.**

A conta `047719652987` e a regiao `us-east-2` aparecem no repositorio em tres
lugares (`fase-2/*/k8s/deployment.yaml`, os `migrate-job.yaml` de flag/targeting,
e o campo `name` das kustomizations) mas **nunca sao puxadas**: sao apenas a
chave que o transformer `images:` usa para casar e reescrever.

Esse nome logico e o acoplamento que o `CLAUDE.md` proibe renomear. Ele liga
tres pontos que precisam mudar juntos ou nenhum:

1. `image:` em `fase-2/<svc>-service/k8s/deployment.yaml`;
2. `images[].name` nas 5 kustomizations;
3. a variavel `OLD_REG` do passo `bump da imagem` em
   [_reusable-ci-service.yml](../.github/workflows/_reusable-ci-service.yml),
   que monta `kustomize edit set image "${OLD_REG}/${SVC}-image=..."`.

**Consequencia pratica:** os `migrate-job.yaml` de flag e targeting declaram
`image: OLD/<svc>-image` sem tag. Isso e deliberado — a mesma entrada de
`images[]` reescreve o Deployment e o Job, garantindo que migration e aplicacao
rodem sempre da mesma imagem. Ja o auth usa imagem separada e por isso precisa da
2ª entrada.

Imagens que **nao** vem do ECR e sobrevivem ao render (relevantes para qualquer
assert de registry): `postgres:16-alpine`, usada nos initContainers `wait-for-db`
dos 3 migrate-jobs e no container do `auth-seed-service-key`.

---

## ConfigMap: o que o patch remove × o que o ESO reinjeta

O ClusterSecretStore e um so, `aws-secrets-manager`
([manifests/platform/clustersecretstore.yaml](gitops/manifests/platform/clustersecretstore.yaml)),
provider AWS SecretsManager, regiao `us-east-1`, autenticando por
`auth.secretRef` no Secret `aws-static-creds` do namespace `external-secrets`
(chaves kebab-case `access-key-id` / `secret-access-key` / `session-token`).

| serviço | chaves que o patch REMOVE do configmap | o que sobra no configmap | chaves que o ESO injeta | secret remoto |
|---|---|---|---|---|
| auth | *(nenhuma)* | `PORT` | `DATABASE_URL`, `MASTER_KEY` | `tc-rds-auth-credentials` (prop. `url`), `tc-auth-app` |
| flag | *(nenhuma)* | `PORT`, `AUTH_SERVICE_URL` | `DATABASE_URL` | `tc-rds-flag-credentials` (prop. `url`) |
| targeting | *(nenhuma)* | `PORT`, `AUTH_SERVICE_URL` | `DATABASE_URL` | `tc-rds-targeting-credentials` (prop. `url`) |
| evaluation | `REDIS_URL`, `AWS_SQS_URL`, `AWS_REGION` | `PORT`, `FLAG_SERVICE_URL`, `TARGETING_SERVICE_URL` | `SERVICE_API_KEY`, `REDIS_URL`, `AWS_SQS_URL`, `AWS_REGION` | `tc-evaluation-app` |
| analytics | `AWS_SQS_URL`, `AWS_DYNAMODB_TABLE`, `AWS_REGION` | `PORT` | `AWS_SQS_URL`, `AWS_DYNAMODB_TABLE`, `AWS_REGION` | `tc-analytics-app` |

O padrao: **so se remove do configmap o que apontava para a conta/regiao da
fase-2** (`us-east-2`, `047719652987`, o endpoint Redis `...use2.cache.amazonaws.com`).
O que e estatico (`PORT`, URLs de servico intra-cluster) fica no configmap.

Note que analytics **nao tem segredo nenhum**: `tc-analytics-app` guarda config
derivada da infra, nao credencial. O ExternalSecret existe so para tirar valor
obsoleto do configmap.

### Credencial AWS: o que o ESO NAO entrega

Os pods que falam direto com a AWS recebem um segundo `secretRef` por patch, e
esse **nao vem do ESO**:

- `evaluation-deployment` → `envFrom: secretRef: aws-session-creds`
- `analytics-deployment` → `envFrom: secretRef: analytics-secret` **e**
  `secretRef: aws-session-creds`

`aws-session-creds` (namespace `toggle`, chaves `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`) e criado por
`null_resource.eso_aws_creds` no `terraform apply`, junto com `aws-static-creds`
(namespace `external-secrets`). Sob o AWS Academy nao ha IRSA e o pod nao alcanca
o IMDS do node, entao esta e a unica fonte de credencial AWS do cluster.
**Expira em ~4h** e e recriado a cada apply (`triggers = { always = timestamp() }`).

---

## `resources:` — o que vem da fase-2 e o que e local

`../../../../` = arquivo da fase-2, reaproveitado sem duplicar.
Sem prefixo = arquivo proprio do overlay.

| serviço | da fase-2 (`../../../../fase-2/...`) | local ao overlay |
|---|---|---|
| auth | `auth-service/k8s/{configmap,deployment,service}.yaml` | `externalsecret.yaml`, `migrate-job.yaml`, `seed-job.yaml` |
| flag | `flag-service/k8s/{configmap,deployment,service}.yaml` | `externalsecret.yaml`, `migrate-job.yaml` |
| targeting | `targeting-service/k8s/{configmap,deployment,service}.yaml` | `externalsecret.yaml`, `migrate-job.yaml` |
| evaluation | `evaluation-service/k8s/{configmap,deployment,service}.yaml`, `evaluation-service/k8s/hpa.yaml` | `externalsecret.yaml` |
| analytics | `analytics-service/k8s/{configmap,deployment,service}.yaml`, `analytics-service/k8s/{kedaauthentication,scaledobject}.yaml` | `externalsecret.yaml` |
| ingress | `fase-2/ingress.yaml` | *(nenhum)* |
| platform | *(nenhum)* | `clustersecretstore.yaml` |

Duas omissoes deliberadas, ambas comentadas no proprio kustomization:

- **`fase-2/<svc>/k8s/secrets.yaml` nao entra em nenhum dos 5** — traz credenciais
  em base64 commitadas. O Secret `<svc>-secret` e materializado pelo ESO.
- **`fase-2/analytics-service/k8s/hpa.yaml` nao entra** — `minReplicas: 3`
  conflitaria com o `ScaledObject` do KEDA (`minReplicaCount: 0`). O KEDA e o
  unico autoscaler do analytics.

O `hpa.yaml` do evaluation **entra** (e o unico HPA em uso).

Todo esse `resources:` so funciona porque o ArgoCD roda com
`kustomize.buildOptions: --load-restrictor LoadRestrictionsNone`, configurado no
Helm values do chart argo-cd em
[modules/addons/main.tf](infra/terraform/modules/addons/main.tf). Sem essa flag,
nenhum dos 7 overlays builda.

---

## Sync-waves em vigor

```
-3  ExternalSecret  (auth, flag, targeting)
-2  Job de migration  (auth, flag, targeting)  + sync-options Replace=true
-1  ExternalSecret  (evaluation, analytics)  /  Application 'platform'
 0  Deployment, Service, ConfigMap, HPA, ScaledObject, Ingress
PostSync (hook)  auth-seed-service-key, hook-delete-policy BeforeHookCreation
```

**Nenhum ExternalSecret e hook.** Sao resources normais com wave negativa. Isso
foi uma correcao (commit `6b4582e`): como hook `PreSync`, o ArgoCD deletava e
recriava o recurso a cada sync, e o ESO ficava em loop
`in deletion` ↔ `reconciled`, travando a fase PreSync.

Os ExternalSecrets de auth/flag/targeting tem `deletionPolicy: Retain` — se o
recurso for pruned, o Secret continua no ar e o pod nao cai. Evaluation e
analytics nao tem.

O unico hook e o `auth-seed-service-key` (PostSync): le `SERVICE_API_KEY` do
`evaluation-secret` e insere o SHA-256 na tabela `api_keys` do banco do auth.
**Ha um acoplamento cross-service aqui:** o Job do overlay do auth le um Secret
que so existe porque o overlay do evaluation foi sincronizado.

---

## Patches ativos — onde o estado atual diverge da fase-2

Toda linha aqui e uma decisao que o render precisa preservar.

| onde | fase-2 | estado atual (lab) | motivo |
|---|---|---|---|
| `replicas` dos 5 Deployments | `3` | `1` | teto de pods baixo no lab (commit `80ab35c`) |
| `evaluation-hpa` | `minReplicas: 3`, `maxReplicas: 10` | `1` .. `3` | idem |
| `analytics-hpa` | existe | **removido do `resources:`** | conflita com o KEDA |
| `analytics-service-scaler` `minReplicaCount` | `0` | `1` | piso ate o KEDA reconciliar |
| `analytics-service-scaler` `triggers[0].queueURL` | `https://sqs.us-east-2.amazonaws.com/047719652987/tc-sqs` | `https://sqs.us-east-1.amazonaws.com/361075236043/tc-sqs` | conta/regiao da fase-3 |
| `analytics-service-scaler` `triggers[0].awsRegion` | `us-east-2` | `us-east-1` | idem |
| `analytics-service-scaler` `triggers[0].identityOwner` | `operator` | **removido** | sem IRSA no Academy |
| `keda-aws-credentials` (TriggerAuthentication) | `spec.podIdentity.provider: aws` | `podIdentity` removido, `secretTargetRef` → `aws-session-creds` | sem IRSA (commit `6bddbf0`) |
| `evaluation-deployment` / `analytics-deployment` `envFrom` | so `configMapRef` (+ `secretRef` no evaluation) | `+ secretRef: aws-session-creds` | credencial AWS estatica |
| `analytics-deployment` `envFrom` | so `configMapRef` | `+ secretRef: analytics-secret` | configmap perdeu 3 chaves |

O `ScaledObject` conserva `maxReplicaCount: 10`, `cooldownPeriod: 300` e
`queueLength: "5"` da fase-2.

---

## Ingress

Um unico Ingress (`fase-2/ingress.yaml`, `ingressClassName: nginx`,
`nginx.ingress.kubernetes.io/rewrite-target: /$2`), com uma regra por servico no
formato `/<svc>(/|$)(.*)` → `<svc>-service:<porta>`. As 5 rotas e as 5 portas
(8001..8005) estao **hard-coded** nesse arquivo da fase-2 — hoje nao ha nada
gerando esse Ingress a partir do `services.yaml`.

Passou a ser gerenciado pelo ArgoCD no commit `77db3c5` (antes era `kubectl apply`
manual). O NLB e criado pelo chart `ingress-nginx` do `modules/addons`.

---

## Infraestrutura por servico (Terraform, `envs/lab`)

| recurso | como e instanciado | quais servicos |
|---|---|---|
| RDS PostgreSQL | `module "rds"` com `for_each = local.rds_services` | auth (`tc-rds-auth`/`auth_db`), flag (`tc-rds-flag`/`flags_db`), targeting (`tc-rds-targeting`/`targeting_db`) |
| ECR | `module "ecr"` com `repositories = local.ecr_repositories` | 5 repos `<svc>-image` **+ `auth-migrate-image` = 6** |
| ElastiCache Redis | `module "elasticache"`, instancia unica | evaluation |
| SQS | `module "sqs"`, fila unica `tc-sqs` | evaluation (producer), analytics (consumer) |
| DynamoDB | `module "dynamodb"`, `hash_key = event_id` | analytics (`tc-dynamo`) |
| Secrets Manager | `aws_secretsmanager_secret` avulsos | `tc-auth-app`, `tc-evaluation-app`, `tc-analytics-app` (os `tc-rds-*-credentials` vem do proprio `module "rds"`) |

**A lista de servicos esta hard-coded em dois locals** — `rds_services` e
`ecr_repositories` — duplicados em `envs/lab/main.tf` e `envs/prod/main.tf`.
Nenhum dos dois le o `services.yaml`. Os secrets de aplicacao sao 3 blocos de
recurso escritos a mao, um por servico.

IAM: o codigo **nao cria Role nem Policy**. `envs/lab` importa a `LabRole` via
`data "aws_iam_role" "lab"`. `envs/prod` tem OIDC e roles proprias, e **nunca foi
aplicado**.

---

## CI (GitHub Actions)

5 callers `.github/workflows/ci-<svc>.yml`, um por servico, cada um so chamando
`_reusable-ci-service.yml` com 4 inputs:

| caller | `service_name` | `service_language` | `working_directory` | `has_migrate_image` |
|---|---|---|---|---|
| ci-auth.yml | auth | go | fase-2/auth-service | **true** |
| ci-flag.yml | flag | python | fase-2/flag-service | false |
| ci-targeting.yml | targeting | python | fase-2/targeting-service | false |
| ci-evaluation.yml | evaluation | go | fase-2/evaluation-service | false |
| ci-analytics.yml | analytics | python | fase-2/analytics-service | false |

Esses 4 inputs sao exatamente as colunas `name`, `language`, `path` e
`db.migrate` do `services.yaml` — a duplicacao que a fonte unica existe para
eliminar.

Estagios do reusable (sequenciais, cada job depende do anterior):
`build-and-test` → `lint` → `security-sast-sca` → `docker-build-scan-push` →
`gitops-update`.

`gitops-update` roda **so** em `push` na branch `lab`, com
`concurrency: gitops-bump-lab`. Faz `kustomize edit set image` no overlay,
commita com `[skip ci]`, `git pull --rebase origin lab` e push. **A tag hoje e o
commit SHA cru** (`${{ github.sha }}`), tanto no push para o ECR quanto no
`newTag` — e por isso que os `newTag` da tabela de imagens sao SHAs de 40 chars.

Auth AWS pela composite action `.github/actions/aws-auth`: branch `lab` → chaves
estaticas de sessao; `main` → OIDC, mas so quando `vars.PROD_AWS_ROLE_ARN` esta
setado (senao `main` tambem cai no lab).

---

## Ferramentas: o que existe e o que nao existe

Levantado nesta maquina no momento do baseline.

| ferramenta | estado |
|---|---|
| `terraform` | **1.16.1** (o README da fase-3 diz que o projeto fixa 1.9.8 — divergencia a confirmar) |
| `tflint` | 0.56.0 |
| `actionlint` | 1.7.12 |
| `make` | GNU Make 4.3 |
| `kustomize` | **AUSENTE** |
| `kubeconform` | **AUSENTE** |
| `checkov` | **AUSENTE** |
| `trivy` | **AUSENTE** |
| `gitleaks` | **AUSENTE** |
| `yq` | **AUSENTE** (snap quebrado) |

**Nao existe Makefile no repositorio.** `make render-diff` e `make lint-*` sao
alvos a criar — nenhum aceite do `ACCEPTANCE.md` e executavel hoje. Por isso o
Makefile e o alvo `tools` sao entrega da etapa 3.

No CI essas ferramentas vem de actions (`aquasecurity/trivy-action`,
`gitleaks` via pre-commit, `checkov` nos workflows de infra), entao a lacuna e
local, nao do pipeline.

---

## Resumo: o que nao pode mudar sem intencao declarada

1. `images[].name` das 5 kustomizations, o `image:` dos deployments da fase-2 e
   `OLD_REG` no `_reusable-ci-service.yml` — mudam juntos ou nenhum.
2. Os nomes das 7 Applications (`<svc>-service`, `platform`, `ingress`) e o da
   root-app (`toggle-master-root`). Nome gerado diferente = orfao.
3. O caminho `fase-3/gitops/root-app.yaml`, lido por `filesha256()` nos dois
   `envs/*/main.tf`. Renomear o arquivo quebra o Terraform.
4. Os `resources: ../../../../fase-2/...` das 7 kustomizations. Mover arquivo
   entre diretorios = OutOfSync.
5. As waves `-3` / `-2` / `-1` / `0` / `PostSync` e o fato de nenhum
   ExternalSecret ser hook.
6. A dependencia cross-service do `auth-seed-service-key` no `evaluation-secret`.
7. `--load-restrictor LoadRestrictionsNone` no `kustomize.buildOptions` do
   ArgoCD.
