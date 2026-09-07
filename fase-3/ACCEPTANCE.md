# ACCEPTANCE — contrato de aceite das etapas 3 a 7 (fase-3)

Definido **antes** da implementacao. Uma etapa so esta pronta quando o
**Comando** sai com exit code 0, a **Equivalencia de render** bate com o que
esta escrito aqui, e o **Invariante estrutural** passa.

Criterio nao muda para acomodar implementacao. Ver **Emenda**, no fim.

Pressupostos de todos os blocos `sh` abaixo:

- execucao a partir da raiz do repositorio;
- `SVC_COUNT="$(yq '.services | length' fase-3/services.yaml)"` (hoje `5`);
- [`fase-3/services.yaml`](services.yaml) e a fonte unica;
- [`fase-3/BASELINE.md`](BASELINE.md) e o retrato do estado que nao pode mudar
  sem intencao declarada.

---

## Definicao de `make render-diff`

Sem isto fixado, "equivalencia de render" nao significa nada.

`make render-diff` renderiza **os 7 overlays** —
`auth`, `flag`, `targeting`, `evaluation`, `analytics`, `platform`, `ingress` —
com

```sh
kustomize build fase-3/gitops/manifests/<overlay> --load-restrictor LoadRestrictionsNone
```

e compara cada saida, `diff -u`, com um snapshot golden versionado em
`fase-3/gitops/.render/<overlay>.yaml`, gerado **uma unica vez** a partir do
estado de `origin/lab` no momento em que este contrato foi escrito. Exit code 0
= render identico ao que esta no ar.

Tres consequencias que valem para todas as etapas:

1. `--load-restrictor LoadRestrictionsNone` nao e opcional: os overlays
   referenciam `../../../../fase-2/...`. E a mesma flag que o ArgoCD usa
   (`kustomize.buildOptions` no chart argo-cd, `modules/addons`). Render local
   com flag diferente do cluster nao prova nada.
2. **`apps/*.yaml` e `root-app.yaml` NAO entram em nenhum overlay.** A root-app
   varre `fase-3/gitops/apps` com `directory.recurse: true`, fora do Kustomize.
   Logo mexer em Application/ApplicationSet **nao move o `render-diff`** — e por
   isso que as etapas 6 e 7 podem exigir render vazio mesmo reescrevendo o
   `apps/`.
3. Regenerar o golden e uma mudanca de contrato: so por Emenda, nunca dentro da
   etapa que o fez divergir.

**Estado hoje:** nao executavel. `kustomize` e `yq` estao ausentes na maquina e
nao ha Makefile no repositorio (ver secao "Ferramentas" do BASELINE). O golden
so passa a existir na etapa 3.

---

## Etapa 3 — Infraestrutura como Codigo (Terraform) + Makefile

Esta etapa entrega tambem a **ferramenta de aceite das outras quatro**. Sem
Makefile, nenhuma etapa deste arquivo e verificavel.

### Comando

```sh
make tools           # instala/verifica kustomize, kubeconform, checkov, trivy, gitleaks, yq
make lint-terraform
```

`make lint-terraform` roda, em sequencia:

- `terraform fmt -check -recursive fase-3/infra`
- `terraform validate` em `envs/lab`, `envs/prod` e em cada `modules/*`
  (sempre com `-backend=false`)
- `tflint --recursive` com `fase-3/infra/terraform/.tflint.hcl`
- `checkov -d fase-3/infra/terraform --config-file fase-3/infra/terraform/.checkov.yaml`
  (`soft-fail: false`)
- `trivy config fase-3/infra/terraform --severity CRITICAL --exit-code 1`

Condicao de saida: exit code 0 nos cinco. `checkov` so passa com a baseline
documentada do Academy — ver "Criterios marcados".

`make tools` deve ser **idempotente e verificavel**: falha dizendo qual binario
falta, nunca instala silenciosamente por baixo do usuario.

### Equivalencia de render

`make render-diff` **vazio nos 7 overlays**. Terraform nao toca YAML
renderizado. Qualquer delta aqui e efeito colateral nao intencional.

Excecao unica e declarada: esta etapa **cria** os goldens em
`fase-3/gitops/.render/`. No commit que os cria, `render-diff` e vacuamente
vazio; a partir do commit seguinte ele e um teste de verdade.

### Invariante estrutural

Vale **a partir da etapa 3**:

```sh
# (a) nenhum arquivo .tf carrega nome de servico no nome do arquivo
test -z "$(find fase-3/infra/terraform -name '*.tf' \
  | grep -E '/(auth|flag|targeting|evaluation|analytics)[-_.]')"

# (b) RDS e ECR instanciados UMA vez cada, via for_each -- nao um module por servico
test "$(grep -rhcE '^\s*module\s+"rds"\s*\{' fase-3/infra/terraform/envs \
        | awk '{s+=$1} END{print s+0}')" -eq 2   # 1 em lab + 1 em prod
test "$(grep -rhcE '^\s*module\s+"ecr"\s*\{' fase-3/infra/terraform/envs \
        | awk '{s+=$1} END{print s+0}')" -eq 2

# (c) nº de repositorios ECR == nº de servicos + nº de servicos com migrate dedicado
MIG="$(yq '[.services[] | select(.db.migrate == "dedicated")] | length' fase-3/services.yaml)"
for e in lab prod; do
  test "$(grep -c 'tech-challenge/' fase-3/infra/terraform/envs/$e/main.tf)" \
    -eq "$((SVC_COUNT + MIG))"
done

# (d) o Makefile existe e expoe os alvos do contrato
for t in tools lint lint-terraform lint-actions lint-gitops lint-registry render-diff; do
  grep -qE "^${t}:" Makefile || exit 1
done
```

Sobre (c): hoje `SVC_COUNT + MIG` = `5 + 1` = **6**, que e o que
`local.ecr_repositories` declara nos dois envs. Se a pergunta **C** do
`services.yaml` for resolvida como "auth deixa de ter imagem dedicada", `MIG`
vira 0 e o invariante passa a exigir 5 — sem mudar uma linha deste arquivo.
E esse o ponto de derivar de `services.yaml`.

### Fora de escopo

- criar Role, Policy de IAM, OIDC provider ou perfis de node dedicados;
- `terraform apply` em qualquer ambiente;
- migrar o state para `use_lockfile` (exige Terraform >= 1.10);
- fazer os `.tf` **lerem** o `services.yaml` (`yamldecode`). Nesta etapa os
  `locals` continuam escritos a mao; o invariante (c) so verifica que a
  contagem bate. Derivacao real e refactor proprio, fora de 3–7;
- qualquer coisa de `envs/prod` alem de `terraform validate` passar.

### Rollback

Nada e aplicado na AWS. `git revert` do commit. Se o `make tools` tiver
instalado binario indesejado, ele mora fora do repo e nao afeta o cluster.

### Criterios marcados — possivelmente inviaveis no lab (IAM restrito)

- **`checkov` de IAM least-privilege (`CKV_AWS_*` de policy/role): inviavel de
  corrigir.** O codigo importa a `LabRole` via `data source` porque o AWS
  Academy **nao permite criar role**. Nao ha o que endurecer — fica em baseline.
- **`checkov` de KMS CMK (`CKV_AWS_119`, `136`, `149`, `191`, `58`): idem.** O
  Academy nao permite criar Customer Managed Key. Ja estao no `skip-check` de
  [.checkov.yaml](infra/terraform/.checkov.yaml).
- `terraform validate` de `envs/prod` (OIDC + IAM proprio) roda **so offline**
  (`-backend=false`) e nunca e aplicado sob o Academy.
- Divergencia de versao: a maquina tem `terraform 1.16.1`, o README da fase-3
  diz que o projeto fixa `1.9.8`. `terraform validate` local pode divergir do
  CI. A etapa deve conferir `versions.tf` e alinhar, ou registrar a diferenca.
- Nenhum invariante desta etapa exige AWS ativa. Todos rodam offline.

---

## Etapa 4 — CI / DevSecOps (GitHub Actions)

### Comando

```sh
make lint-actions
```

Roda `actionlint` em `.github/workflows/*.yml` e `.github/actions/*/action.yml`,
mais as assercoes estruturais abaixo.

Condicao de saida: exit code 0; `actionlint` sem erro nem warning; todo workflow
por servico e **apenas um caller** de `_reusable-ci-service.yml`, sem logica de
build, test, scan ou deploy inline.

### Equivalencia de render

`make render-diff` **vazio nos 7**. Mudar CI nao pode alterar YAML renderizado.

Cuidado especifico: o job `gitops-update` escreve `newTag` nos overlays. Se a
etapa rodar o CI de verdade durante o trabalho, o `newTag` muda e o
`render-diff` acusa. Isso **nao** e falha de contrato — e sinal de que o golden
precisa ser regenerado por Emenda, ou de que a verificacao deve rodar antes do
push para `lab`. O contrato exige render vazio para o **diff da etapa**, nao
para o repositorio depois de um deploy.

### Invariante estrutural

Vale **a partir da etapa 4**:

```sh
# (a) cada caller e SO um caller: nenhum steps:/run: proprio, exatamente um
#     uses:, e esse uses: e o reusable de servico
for f in .github/workflows/ci-*.yml; do
  grep -qE '^\s*(steps|run):' "$f" && exit 1
  test "$(grep -cE '^\s*uses:' "$f")" -eq 1 || exit 1
  grep -q '_reusable-ci-service.yml' "$f" || exit 1
done

# (b) exatamente 1 workflow reutilizavel de servico
test "$(ls .github/workflows/_reusable-*.yml | wc -l)" -eq 1

# (c) nº de callers == nº de servicos em services.yaml
test "$(ls .github/workflows/ci-*.yml | wc -l)" -eq "$SVC_COUNT"

# (d) nenhum deploy imperativo no CI de APLICACAO -- deploy e do ArgoCD.
#     Escopo: so os workflows de servico, e so linhas de codigo (nao comentario).
test -z "$(grep -hE '^[^#]*kubectl apply' \
  .github/workflows/ci-*.yml .github/workflows/_reusable-*.yml)"

# (e) cada caller declara os inputs que batem com services.yaml
yq -r '.services[] | "\(.name) \(.language) \(.path)"' fase-3/services.yaml \
| while read -r name lang path; do
    f=".github/workflows/ci-${name}.yml"
    grep -q "service_language: ${lang}" "$f" || exit 1
    grep -q "working_directory: ${path}" "$f" || exit 1
  done
```

O invariante (e) e o que impede o `services.yaml` de virar documentacao morta:
se alguem mudar a linguagem de um servico so no workflow, o aceite quebra.

Duas notas sobre a forma dos invariantes (a) e (d), levantadas ao rodar o
contrato contra o estado atual:

- **(a) nao conta linhas.** Um limite tipo "< 20 linhas uteis" reprovaria os
  callers de hoje (27 linhas uteis cada, quase todas blocos `paths:`
  legitimos) e ficaria mais errado ainda depois da etapa 6, que **acrescenta**
  triggers `release:` e `tags:`. O que importa nao e tamanho: e o caller nao ter
  logica propria. Por isso o assert e "zero `steps:`/`run:`, exatamente um
  `uses:`, e esse `uses:` e o reusable".
- **(d) e escopado aos workflows de servico e ignora comentario.** Um
  `grep -rl 'kubectl apply' .github/workflows` casa hoje com a linha 96 de
  `infra-tf-apply.yml`, que e um **comentario** explicando o
  `null_resource.root_app`. E os workflows de infra legitimamente disparam
  `kubectl apply` por dentro do Terraform (`local-exec` do root-app e dos
  Secrets de credencial). A regra "deploy e do ArgoCD" vale para o CI de
  aplicacao, nao para o bootstrap da plataforma.

### Fora de escopo

- assinatura de imagem, SLSA provenance, SBOM publicado;
- deploy de aplicacao (e do ArgoCD, etapa 5);
- teste de carga e gate de cobertura minima;
- suportar linguagem alem de `go` e `python` no reusable;
- colapsar os 5 callers em 1 workflow com matrix — **nao e desta etapa e nao e
  de nenhuma das etapas 3 a 7.** O invariante (c) exige explicitamente 5
  arquivos.

### Rollback

Workflow nao muda cluster. `git revert`. Se um push para `lab` ja tiver bumpado
imagem errada, o rollback e o da etapa 5 (revert do `newTag` + sync).

### Criterios marcados

- Callers em `push` para `lab` dependem dos secrets de sessao
  `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`, que
  expiram em ~4h sob o Academy. O aceite desta etapa e **puramente estatico** e
  roda em qualquer ambiente — nao valida execucao real.
- O estagio `gitops-update` so tem efeito com push real na branch `lab`; nao e
  coberto por `make lint-actions`. Intencional.

---

## Etapa 5 — Entrega Continua (GitOps / ArgoCD)

### Comando

```sh
make lint-gitops
```

Para cada um dos 7 overlays:
`kustomize build ... --load-restrictor LoadRestrictionsNone | kubeconform -strict -ignore-missing-schemas`.

Condicao de saida: todo build conclui; `kubeconform` nao reporta manifesto
invalido; nenhum build contem `kind: Secret` com `data:` em base64.

`-ignore-missing-schemas` e necessario para os CRDs (`ExternalSecret`,
`ClusterSecretStore`, `ScaledObject`, `TriggerAuthentication`) — nao ha schema
publicado para eles no catalogo padrao.

### Equivalencia de render

`make render-diff` **vazio nos 7**. Esta etapa nao muda o que o cluster recebe;
ela adiciona a capacidade de provar que nao mudou.

### Invariante estrutural

Vale **a partir da etapa 5**:

```sh
# (a) nenhum Secret versionado no GitOps
test -z "$(grep -rl '^kind: Secret' fase-3/gitops/manifests)"

# (b) no maximo 1 ponto de bump por imagem de aplicacao no overlay
#     (auth tem 2 entradas em images[]: app + migrate dedicado)
yq -r '.services[] | "\(.name) \(.db.migrate // "none")"' fase-3/services.yaml \
| while read -r name mig; do
    expected=1; [ "$mig" = "dedicated" ] && expected=2
    k="fase-3/gitops/manifests/${name}/kustomization.yaml"
    test "$(grep -c 'newTag:' "$k")" -eq "$expected" || exit 1
  done

# (c) nº de overlays de servico == SVC_COUNT (platform e ingress nao sao servicos)
test "$(ls -d fase-3/gitops/manifests/*/ \
  | grep -vE '/(platform|ingress)/$' | wc -l)" -eq "$SVC_COUNT"

# (d) todo servico do services.yaml tem overlay, e vice-versa
yq -r '.services[].name' fase-3/services.yaml | while read -r n; do
  test -f "fase-3/gitops/manifests/${n}/kustomization.yaml" || exit 1
done

# (e) nenhum overlay de servico referencia a fase-2 -- ver Emenda 001.
#     Escopo: os 5 servicos. platform e ingress ficam de fora de proposito.
yq -r '.services[].name' fase-3/services.yaml | while read -r n; do
  test -z "$(grep -rl '\.\./fase-2/' \
    "fase-3/gitops/manifests/${n}" "fase-3/${n}/k8s" 2>/dev/null)" || exit 1
done

# (f) transformer de imagem unico -- ver Emenda 001.
#     Exatamente UMA kustomization por servico declara o campo images:, e ela e
#     a que o gitops-update escreve. Zero = ImagePullBackOff (falha visivel).
#     Duas = o filho reescreve OLD->NEW, o pai nao casa nada, bump verde sem
#     deploy (falha silenciosa). Conta CAMPOS images:, nao entradas -- auth tem
#     2 entradas num campo so, e o invariante (b) e quem cuida disso.
yq -r '.services[].name' fase-3/services.yaml | while read -r n; do
  test "$(grep -c '^images:' "fase-3/gitops/manifests/${n}/kustomization.yaml")" \
    -eq 1 || exit 1
  test -z "$(grep -rl '^images:' "fase-3/${n}/k8s/base" 2>/dev/null)" || exit 1
done
```

Os invariantes (e) e (f) entram por **Emenda 001** e nascem falhando: (e) so
passa conforme cada servico e consolidado, e e por isso que ele esta escopado aos
5 servicos do `services.yaml`. **`platform` e `ingress` continuam referenciando a
fase-2** e nao sao alvo desta etapa — logo o
`--load-restrictor LoadRestrictionsNone` **continua obrigatorio** em
`render-diff`, `lint-gitops` e `lint-registry`, exatamente como a "Definicao de
`make render-diff`" fixa. A flag deixa de ser *necessaria* para os 5 servicos;
ela nao e *removida* de lugar nenhum.

**`ls fase-3/gitops/*.yaml | wc -l == 1` NAO e invariante desta etapa.** Hoje
esse comando ja retorna 1 — o `root-app.yaml` — por coincidencia, nao por
design. Ele so vira criterio na etapa 7, com outro significado. Assertar aqui
daria um verde falso.

### Fora de escopo

- instalar ou atualizar o ArgoCD (e `modules/addons`, etapa 3);
- progressive delivery (Argo Rollouts, canary, blue-green);
- politica de sync-wave alem da ja registrada no BASELINE;
- autenticacao, RBAC ou ingress da UI do ArgoCD;
- trocar Application por ApplicationSet — **e a etapa 7**;
- remover `--load-restrictor LoadRestrictionsNone` do `kustomize.buildOptions` do
  chart (`modules/addons`) ou dos alvos do Makefile. So faz sentido quando os
  **7** overlays estiverem livres da fase-2, e e mudanca de cluster: e refactor
  proprio, fora de 3–7. Ver Emenda 001.

### Rollback

`git revert` do commit na branch `lab` e aguardar o `selfHeal` (ou
`argocd app sync <app>`). Se um overlay entrar em Degraded, o caminho e reverter
o `newTag` para o valor registrado no BASELINE e ressincronizar — nunca editar
recurso vivo com `kubectl`.

Os ExternalSecrets de auth/flag/targeting tem `deletionPolicy: Retain`: um prune
acidental nao derruba o Secret nem o pod. Evaluation e analytics **nao** tem —
prune ali derruba.

### Criterios marcados

- ESO e KEDA rodam sem IRSA (Academy) e dependem dos Secrets
  `aws-static-creds` / `aws-session-creds`, criados por `local-exec` no
  `terraform apply` e com token de ~4h. `kustomize build` + `kubeconform`
  validam **forma**, nao existencia em runtime. O aceite estrutural roda
  offline; o sync real so funciona depois de um apply recente.
- `kubeconform -strict` nao valida os CRDs de ESO/KEDA. Erro de campo dentro de
  um `ScaledObject` passa pelo lint e so aparece no cluster. Limitacao
  conhecida, aceita.

---

## Etapa 6 — Versionamento de imagem no CI

Modifica `_reusable-ci-service.yml` e os `ci-<svc>.yml`. Alteracao minima, sem
reescrita.

### Comando

```sh
make lint-actions
make lint-registry
make render-diff     # tem de sair vazio
```

`make lint-registry` renderiza os 7 overlays e afirma que **toda** imagem
resultante ou comeca com o registry esperado do ambiente
(`361075236043.dkr.ecr.us-east-1.amazonaws.com/tech-challenge/` no lab) ou
consta de uma allow-list explicita de imagens de terceiros. E o mesmo alvo que o
CI reusa no passo de guarda pos-build — nao ha duas implementacoes.

### Equivalencia de render

`make render-diff` **vazio nos 7**, e isso e o coracao do aceite desta etapa.

Escrito antes da execucao: a etapa 6 troca **a origem** da variavel de tag
(`$TAG` calculado a partir de `github.ref_type`, em vez de `github.sha` cru).
A mecanica do bump permanece: `kustomize edit set image ...:${TAG}`. Nenhum
`newTag` ja commitado deve mudar no diff da etapa. **Se qualquer `newTag` mudar,
a etapa violou o proprio contrato** — significa que ela rodou o CI e deixou o
deploy entrar junto com o refactor.

### Invariante estrutural

Vale **a partir da etapa 6**:

```sh
# (a) allow-list de imagens de terceiros e explicita e versionada
test -f fase-3/gitops/.render/allowed-images.txt

# (b) toda imagem renderizada e do registry do ambiente ou esta na allow-list
for o in auth flag targeting evaluation analytics platform ingress; do
  kustomize build "fase-3/gitops/manifests/$o" --load-restrictor LoadRestrictionsNone \
  | grep -oE '^\s*(- )?image:\s*\S+' | awk '{print $NF}' | sort -u \
  | while read -r img; do
      case "$img" in
        361075236043.dkr.ecr.us-east-1.amazonaws.com/tech-challenge/*) ;;
        *) grep -qxF "$img" fase-3/gitops/.render/allowed-images.txt || exit 1 ;;
      esac
    done
done

# (c) os 5 callers disparam por tag alem dos triggers de branch
for f in .github/workflows/ci-*.yml; do
  grep -q 'release:' "$f" || exit 1
  grep -qE "tags:.*/v\*" "$f" || exit 1
done

# (d) o reusable empurra DUAS tags: a semantica e a rastreavel por SHA
grep -q 'sha-' .github/workflows/_reusable-ci-service.yml

# (e) o passo de guarda do reusable reusa o alvo, nao reimplementa
grep -q 'lint-registry' .github/workflows/_reusable-ci-service.yml
```

**A allow-list nao e opcional.** Sem ela o invariante (b) reprova o estado atual:
o render contem `postgres:16-alpine` nos initContainers `wait-for-db` dos 3
migrate-jobs e no container do `auth-seed-service-key`. O conteudo inicial de
`allowed-images.txt` e exatamente uma linha:

```text
postgres:16-alpine
```

Acrescentar linha a esse arquivo e mudanca de superficie de confianca: exige
justificativa no PR, na mesma logica da baseline do checkov.

### Defeito conhecido na especificacao desta etapa

O formato de fallback especificado, `0.0.0-lab.${run_number}+${sha:0:7}`, **e
uma tag OCI invalida.** Tags de registry aceitam
`[a-zA-Z0-9_][a-zA-Z0-9._-]{0,127}`; `+` nao pertence a esse conjunto. Build
metadata de SemVer nao sobrevive a um registry: `docker push` e
`kustomize edit set image` falham.

A etapa deve escolher um separador valido (`0.0.0-lab.N-sha7` ou
`0.0.0-lab.N_sha7`) **antes** de implementar. Isto esta escrito aqui de
proposito: e uma correcao de fato tecnico verificavel, nao um afrouxamento de
criterio, e por isso nao precisa de Emenda.

### Fora de escopo

- **pinning por digest (`@sha256:...`)** — registrado como proximo passo,
  explicitamente nao implementado nesta etapa;
- assinatura de imagem (cosign) e attestation;
- mudar a mecanica do bump ou o `OLD_REG` do `kustomize edit set image`;
- retagear imagens ja publicadas no ECR;
- politica de lifecycle/retencao no ECR.

### Rollback

`git revert` dos workflows. Imagens ja publicadas com o formato novo continuam
no ECR e continuam validas — o `newTag` nos overlays nao muda no revert, entao
o cluster nao se mexe. Se um bump com tag invalida tiver sido commitado, reverter
o `newTag` para o valor do BASELINE e `argocd app sync`.

### Criterios marcados

- `make lint-registry` compara com o registry **do lab**. Quando `envs/prod`
  for ativado, o alvo precisa parametrizar a conta — hoje o valor e fixo, e
  isso e consciente.
- Nada nesta etapa exige AWS ativa. `lint-registry` e `render-diff` rodam
  offline sobre o render local.

---

## Etapa 7 — ApplicationSet (adocao, nao recriacao)

A etapa de maior risco do contrato: transfere ownership de Applications vivas.

### Comando

```sh
make render-diff     # vazio
make lint-gitops
```

### Pre-condicao bloqueante

**Antes de aplicar qualquer coisa no cluster**, `argocd app diff` de cada uma
das Applications adotadas tem de sair vazio. Se qualquer uma nao sair,
**PARAR**. Nao aplicar. Um `app diff` nao-vazio significa que o cluster ja
divergiu do git, e adotar nesse estado mistura duas mudancas.

Isto e pre-condicao, nao criterio de saida: falhar aqui interrompe a etapa sem
gerar Emenda.

### Equivalencia de render

`make render-diff` **vazio nos 7**. Vale porque `apps/` e `root-app.yaml` estao
fora do Kustomize (ver "Definicao de `make render-diff`", consequencia 2): o
ApplicationSet pode ser reescrito inteiro sem mover uma linha do render.

Se o `render-diff` acusar delta nesta etapa, a etapa tocou overlay — o que ela
nao deveria fazer.

### Invariante estrutural

Vale **a partir da etapa 7** (e so a partir dela):

```sh
# (a) um unico arquivo YAML na raiz de fase-3/gitops, e ele e um ApplicationSet
test "$(ls fase-3/gitops/*.yaml | wc -l)" -eq 1
grep -q '^kind: ApplicationSet' fase-3/gitops/*.yaml

# (b) o diretorio apps/ com um Application por servico deixou de existir
test ! -d fase-3/gitops/apps

# (c) politica de transicao explicita no ApplicationSet
grep -q 'preserveResourcesOnDeletion: true' fase-3/gitops/*.yaml
grep -qE 'applicationsSync: (create-only|create-update)' fase-3/gitops/*.yaml
```

**Atencao ao invariante (a): ele ja retorna 1 hoje**, porque
`fase-3/gitops/root-app.yaml` e o unico YAML nessa raiz. O criterio so tem
sentido junto com (b) e com o `grep` de `kind: ApplicationSet` — o par
"exatamente 1 arquivo **e** ele e ApplicationSet **e** apps/ nao existe mais" e
que prova a consolidacao. Assertar (a) sozinho da verde falso.

### Sintaxe confirmada (nao assumida de memoria)

Conferido na documentacao oficial do ArgoCD
(`operator-manual/applicationset/Controlling-Resource-Modification`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
spec:
  syncPolicy:
    applicationsSync: create-only          # create-only | create-update | create-delete | sync
    preserveResourcesOnDeletion: true
```

Na transicao: `create-only` + `preserveResourcesOnDeletion: true`. So depois de
confirmar que o ApplicationSet adotou todas — `ownerReference` presente no
Application e status `Synced`/`Healthy` — e que a politica aperta.

Ponto a confirmar na execucao: o override de `applicationsSync` por
ApplicationSet pode exigir flag no applicationset-controller
(`ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_POLICY_OVERRIDE`) dependendo da versao
do chart. A versao vem de `var.argocd_chart_version` em
[modules/addons/main.tf](infra/terraform/modules/addons/main.tf). Confirmar
contra a versao instalada antes de escrever o manifesto.

### Decisoes pendentes que esta etapa nao pode resolver sozinha

Tres fatos verificados contradizem a especificacao da etapa. Nenhum e ajustavel
dentro dela; todos exigem decisao previa, registrada por Emenda:

1. **O ApplicationSet substitui o `root-app.yaml`, e o Terraform quebra.**
   `root-app.yaml` e lido por `local.gitops_root_app_path` em
   `envs/lab/main.tf` e `envs/prod/main.tf`, aplicado por
   `null_resource.root_app` com trigger `filesha256(...)`. O invariante (a) so
   passa se esse arquivo deixar de existir — o que torna a etapa 7 uma mudanca
   de **GitOps + Terraform no mesmo commit**, e transfere o ownership do
   Application `toggle-master-root`.
2. ~~**O generator especificado aponta para um caminho inexistente.**~~
   **RESOLVIDO por Emenda 001.** O overlay lab permanece em
   `fase-3/gitops/manifests/<svc>/`; `fase-3/<svc>/k8s/overlays/lab/` nao existe
   e nao deve ser criado. O generator desta etapa aponta para
   `fase-3/gitops/manifests/*` — **um unico git directory generator**, que cobre
   os 7 (5 servicos + `platform` + `ingress`) e resolve tambem parte da decisao 3.
   Nao ha necessidade de dois generators enquanto `envs/prod` nao for ativado, o
   que esta fora de 3–7.
3. **Sao 7 Applications, nao 5.** Alem dos 5 servicos existem `platform`
   (namespace `external-secrets`, sync-wave `-1`, dona do `ClusterSecretStore`)
   e `ingress`. O ApplicationSet precisa dizer o que faz com as duas — segundo
   generator, entradas fixas de um list generator, ou permanecerem como
   Application avulsa (o que quebra o invariante (a)). Com `prune: true` ativo,
   deixar qualquer uma orfa e derrubar recurso vivo. `platform` em particular:
   se cair, todos os ExternalSecrets param de reconciliar.

**Requisito de nomes:** o template tem de gerar **exatamente** os nomes que
existem hoje — `auth-service`, `flag-service`, `targeting-service`,
`evaluation-service`, `analytics-service` (mais `platform` e `ingress`, conforme
a decisao 3). Divergencia de um caractere = Application orfa.

### Fora de escopo

- mudar qualquer overlay (por definicao: `render-diff` tem de sair vazio);
- progressive delivery;
- apertar a politica para `sync` / `create-delete` no mesmo commit da adocao —
  e um segundo commit, depois da confirmacao de ownership;
- gerar as Applications de `platform`/`ingress` a partir do `services.yaml`
  (nao sao servicos);
- migrar o `targetRevision` de `lab` para algo por ambiente.

### Rollback

`applicationsSync: create-only` + `preserveResourcesOnDeletion: true` sao
justamente o mecanismo de rollback: deletar o ApplicationSet **nao** deleta as
Applications nem os recursos. Sequencia:

1. `kubectl delete applicationset <nome> -n argocd` (as Applications sobrevivem);
2. `git revert` do commit — restaura `apps/*.yaml` e `root-app.yaml`;
3. reaplicar a root-app (`kubectl apply -f fase-3/gitops/root-app.yaml` ou
   novo `terraform apply`, ja que `null_resource.root_app` dispara por
   `filesha256`);
4. conferir `argocd app list` — as 7 Applications de volta com os nomes do
   BASELINE.

Se aparecer orfa: **nao deletar com prune ativo.** Primeiro
`kubectl patch app <nome> -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'`
para desarmar prune/selfHeal, e so entao investigar.

### Criterios marcados

- `argocd app diff` exige CLI autenticada contra o cluster do lab, que por sua
  vez depende de credenciais de sessao de ~4h. E a **unica** pre-condicao deste
  contrato que nao roda offline. Os criterios de saida (`render-diff`,
  `lint-gitops`, invariantes) continuam offline.
- Nada aqui envolve IAM: o ApplicationSet e recurso de cluster. O Academy nao
  impoe restricao nesta etapa.

---

## Estado dos invariantes no momento em que este contrato foi escrito

Todo bloco `sh` acima foi executado contra o estado atual (`HEAD` == `origin/lab`).
Um invariante que ja falha hoje **sem** estar marcado "vale a partir da etapa N"
seria bug do contrato — nao ha nenhum na tabela.

| invariante | hoje | quando passa a valer |
| --- | --- | --- |
| 3a nenhum `.tf` com nome de servico | PASSA | etapa 3 |
| 3b `module rds` / `module ecr` uma vez por env | PASSA | etapa 3 |
| 3c nº de repos ECR == `SVC_COUNT + MIG` (= 6) | PASSA | etapa 3 |
| 3d Makefile com os 7 alvos | **FALHA** | etapa 3 — e a entrega |
| 4a caller sem logica propria | PASSA | etapa 4 |
| 4b exatamente 1 reusable | PASSA | etapa 4 |
| 4c nº de callers == `SVC_COUNT` | PASSA | etapa 4 |
| 4d nenhum `kubectl apply` no CI de aplicacao | PASSA | etapa 4 |
| 4e inputs dos callers batem com `services.yaml` | PASSA | etapa 4 |
| 5a nenhum Secret versionado | PASSA | etapa 5 |
| 5b `newTag` por overlay (auth=2, resto=1) | PASSA | etapa 5 |
| 5c overlays de servico == `SVC_COUNT` | PASSA | etapa 5 |
| 5d todo servico tem overlay | PASSA | etapa 5 |
| 5e nenhum overlay de servico referencia a fase-2 | **FALHA** | etapa 5 — Emenda 001 |
| 5f exatamente 1 campo `images:` por servico | a verificar | etapa 5 — Emenda 001 |
| 6a `allowed-images.txt` existe | **FALHA** | etapa 6 |
| 6b toda imagem no registry do ambiente ou na allow-list | nao executavel (sem `kustomize`) | etapa 6 |
| 6c callers disparam por `release`/tag | **FALHA** | etapa 6 |
| 6d reusable empurra a 2ª tag `sha-` | **FALHA** | etapa 6 |
| 6e reusable reusa `lint-registry` | **FALHA** | etapa 6 |
| 7a contagem `ls fase-3/gitops/*.yaml == 1` | **PASSA — verde falso** | ver nota |
| 7a `kind: ApplicationSet` | **FALHA** | etapa 7 |
| 7b `apps/` deixou de existir | **FALHA** | etapa 7 |
| 7c politica de transicao declarada | **FALHA** | etapa 7 |

**A nota do 7a e o ponto mais importante desta tabela.** A contagem ja retorna 1
hoje porque `root-app.yaml` e o unico YAML naquela raiz. Sozinho, esse assert da
verde num estado que nao tem ApplicationSet nenhum. So o conjunto
7a-contagem + 7a-kind + 7b prova a consolidacao.

Nao executavel hoje, por ferramenta ausente: tudo que depende de `kustomize`
(`render-diff`, `lint-gitops`, `lint-registry` 6b) e de `yq` (`SVC_COUNT`,
3c, 4e, 5b). Passa a ser executavel quando a etapa 3 entregar `make tools`.

---

## `make lint` (agregador)

`make lint` executa `lint-terraform`, `lint-actions`, `lint-gitops`,
`lint-registry` e `gitleaks detect --no-banner`.

Uma etapa nunca e dada por concluida sem o **seu** alvo especifico verde.
`make lint` verde e o criterio de aceite do conjunto, nao substituto do alvo da
etapa.

---

## Emenda

Qualquer criterio deste arquivo — Comando, Equivalencia de render, Invariante
estrutural, Fora de escopo ou Rollback — so pode ser alterado por **commit
dedicado** que:

1. toque **apenas** `fase-3/ACCEPTANCE.md` — nenhum outro arquivo no mesmo
   commit;
2. use a mensagem `docs(acceptance): <o que mudou>` e descreva no corpo a
   **justificativa** e a etapa afetada;
3. seja feito **fora** da execucao de uma etapa — nunca como reacao a um
   invariante que falhou no meio do trabalho.

Regenerar os goldens de `fase-3/gitops/.render/` conta como alteracao de
criterio e segue as mesmas tres regras (o commit toca o ACCEPTANCE e os
goldens, e nada mais).

Afrouxar um invariante para "fazer a etapa passar" durante a propria etapa e
proibido. O caminho e: parar, abrir o commit de emenda, justificar, e so entao
retomar.

**Nao e Emenda** corrigir um fato tecnico verificavelmente errado escrito neste
arquivo — por exemplo, a tag OCI invalida documentada na etapa 6. Fato errado
se corrige; criterio se emenda.

---

## Emendas registradas

### Emenda 001 — fonte de verdade do overlay lab

- **Data:** 2026-09-07
- **Status:** DECIDIDO. Nao e divida tecnica; nao reabrir.
- **Fecha:** pergunta D de [services.yaml](services.yaml); etapa 7, decisao
  pendente 2.
- **Motivador:** consolidacao do servico `flag`, interrompida por conflito entre
  o passo "apontar a kustomization para o novo overlay" e os invariantes 5b/5c/5d.

#### Decisao

O overlay lab **permanece** em `fase-3/gitops/manifests/<svc>/`.
`fase-3/<svc>/k8s/` passa a conter `base/` e, quando existirem, os overlays
`local` e `prod`. O caminho `fase-3/<svc>/k8s/overlays/lab/` **nao existe e nao
deve ser criado**. A consolidacao de um servico consiste em mover a base real
para `fase-3/<svc>/k8s/base/` e trocar o `resources:` do overlay lab para
apontar para ela.

#### Justificativa

1. **A alternativa do stub e insegura, nao apenas nao-conforme.** Transformar
   `manifests/<svc>/kustomization.yaml` num stub sem campo `images:` nao para de
   pe: o `kustomize edit set image` do `gitops-update` **cria** o campo na
   primeira execucao, chaveado por `OLD_REG`. O overlay filho ja reescreveu
   `OLD -> NEW`, o transformer do pai nao casa nenhum container, e o resultado e
   bump verde sem deploy. A falha e silenciosa e **reintroduzida por automacao**,
   nao por escolha de quem edita. Dai o invariante 5f.
2. **Mover de verdade nao cabe em "um servico por vez".** Exigiria commit unico
   tocando os 5 servicos, o `_reusable-ci-service.yml` (`working-directory` e
   `git add` derivam de `inputs.service_name` e sao compartilhados), os
   invariantes 5b/5c/5d e a propria "Definicao de `make render-diff`" — e sem
   portao de equivalencia utilizavel durante a transicao.
3. **O ganho pretendido e entregue mesmo assim.** O objetivo da consolidacao era
   eliminar `../../../../fase-2/`, nao igualar caminhos. Com a base em
   `fase-3/<svc>/k8s/base/`, o overlay lab passa a referenciar
   `../../../<svc>/k8s/base`, que e referencia a diretorio de kustomization e
   nao depende do restritor. A simetria de caminho entre os tres overlays era
   estetica.

#### O que esta Emenda NAO altera

- invariantes 5a, 5b, 5c, 5d;
- a "Definicao de `make render-diff`", inclusive o uso obrigatorio de
  `--load-restrictor LoadRestrictionsNone`;
- `_reusable-ci-service.yml`, em qualquer aspecto;
- os 4 servicos ainda nao consolidados;
- o escopo de `platform` e `ingress`, que seguem referenciando a fase-2.

#### Sobre o restritor — correcao de premissa

Uma versao anterior desta Emenda proibia `--load-restrictor LoadRestrictionsNone`
no repositorio. **Isso contradiz este contrato e esta errado de fato:** a flag e
exigida por `render-diff`, `lint-gitops` e `lint-registry` (6b), e espelha o
`kustomize.buildOptions` com que o ArgoCD do lab constroi
(`modules/addons`). Render local com flag diferente do cluster nao prova nada.

A regra correta e a do invariante 5e: **ausencia de `../fase-2/` nos 5
servicos**. A flag deixa de ser necessaria para eles e continua obrigatoria
enquanto `platform` e `ingress` dependerem da fase-2. Remove-la do chart e do
Makefile e refactor proprio, fora das etapas 3–7.

#### Consequencia para a etapa 7 — correcao

Uma versao anterior desta Emenda afirmava que seriam necessarios dois
generators. **Nao sao.** Com o lab onde esta, os 7 overlays vivem sob
`fase-3/gitops/manifests/`, e um unico git directory generator sobre
`fase-3/gitops/manifests/*` cobre todos. A questao de dois generators so
aparece quando `envs/prod` for ativado e passar a existir overlay de prod em
outra arvore — o que esta explicitamente fora de 3–7.

#### Estado dos novos invariantes na data da Emenda

`5e` nasce **falhando** e passa servico a servico, conforme a consolidacao
avanca — comportamento pretendido: o contrato exige antes de a implementacao
entregar. `5f` **precisa ser executado** contra `HEAD` e o resultado registrado
na tabela de estado; ele foi escrito a partir da leitura do repositorio, nao de
uma execucao.
