<div align="center">
  <br/>
  <hr style="border: none; border-top: 1px solid #ED145B; width: 100%; margin: 0 auto"/>
</div>

![/.github/LOGO-FIAP.png](/.github/LOGO-FIAP.png)

# Tech Challenge - Objetivos da Fase 3

Na Fase 2, evoluímos o Toggle Master de monolito para uma arquitetura de microsserviços containerizada em Kubernetes. No entanto, a operação continuava manual: deploys feitos via `kubectl apply` a partir de máquinas locais, credenciais de banco em arquivos de texto e ambientes recriados manualmente pelo console AWS. Na Fase 3, o objetivo é eliminar esse trabalho manual: "se não está no código, não existe".

Automatizamos toda a infraestrutura e o ciclo de vida dos 5 microsserviços do ToggleMaster (`auth`, `flag`, `targeting`, `evaluation`, `analytics`) com **Infraestrutura como Código (Terraform)**, **pipelines de CI/DevSecOps** e **entrega contínua via GitOps com ArgoCD**.

## Entregáveis da Fase 3

1. **Vídeo de Demonstração (até 20 minutos):** [link do vídeo]

2. **Documentação Separada por Tópicos:**

- [O Problema: Operação Insustentável](#o-problema-operação-insustentável);
- [Infraestrutura como Código (Terraform)](#infraestrutura-como-código-terraform);
- [Backend Remoto do Terraform State](#backend-remoto-do-terraform-state);
- [Pipeline de CI & DevSecOps](#pipeline-de-ci--devsecops);
- [Entrega Contínua (CD) & GitOps](#entrega-contínua-cd--gitops);
- [Dificuldades Encontradas](#dificuldades-encontradas);
- [Estimativa de Custos](#estimativa-de-custos);
- [Diagrama de Arquitetura](#diagrama-de-arquitetura);
- [Integrantes do Grupo](#integrantes-do-grupo);

3. **Código Fonte no Repositório:**

- Código Terraform completo, organizado em módulos.
- Workflows de CI/CD (GitHub Actions) com os passos de DevSecOps.
- Manifestos Kubernetes ajustados para GitOps.

4. **Relatório de Entrega (.PDF ou .txt):** nomes dos participantes, link da documentação e do vídeo, resumo de desafios/decisões e print da estimativa de custos da AWS.

5. **Integrantes do Grupo**:

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)

> **Importante — Ambiente de Nuvem (Terraform & IAM):** assim como nas fases anteriores, trabalhamos sob as restrições do AWS Academy: o código Terraform **não cria Roles ou Policies de IAM**. O cluster EKS e os Node Groups utilizam a `LabRole` existente, importada via `data source` do Terraform.

## O Problema: Operação Insustentável

A arquitetura de microsserviços aprovada na Fase 2 trouxe quatro problemas operacionais que motivam a Fase 3:

- **Deploys manuais e conflitantes:** desenvolvedores rodando `kubectl apply` a partir de máquinas locais, sem fonte única de verdade, gerando conflitos de versão entre ambientes.
- **Credenciais inseguras:** credenciais de banco de dados trafegando em arquivos de texto sem criptografia ou gestão de secrets.
- **Vulnerabilidades não detectadas:** uma vulnerabilidade em uma biblioteca Go chegou à produção sem ser barrada em nenhuma etapa do processo.
- **Ambientes não reprodutíveis:** recriar o ambiente de homologação levava dias, por ter sido provisionado manualmente no console AWS.

A resposta a esses quatro pontos é, respectivamente: GitOps (fonte única de verdade), DevSecOps com secrets gerenciados, security scanning obrigatório no pipeline, e Infraestrutura como Código.

## Infraestrutura como Código (Terraform)

Toda a infraestrutura que era provisionada manualmente na Fase 2 foi substituída por um projeto Terraform organizado em módulos, provisionando:

1. **Networking:** VPC, Subnets públicas e privadas, Internet Gateway e Route Tables.
2. **Cluster EKS:** cluster Kubernetes e Node Groups, associados à `LabRole` do AWS Academy.
3. **Bancos de Dados:**
   - 3 instâncias RDS (PostgreSQL) — uma para cada serviço com dados relacionais (`auth-service`, `flag-service`, `targeting-service`), preservando o isolamento de *database-per-service* já adotado na Fase 2.
   - 1 Cluster ElastiCache (Redis).
   - 1 tabela DynamoDB (`ToggleMasterAnalytics`), usada pelo `analytics-service`.
4. **Mensageria:** 1 fila SQS, consumida pelo `analytics-service` e usada como gatilho de escalabilidade do KEDA.
5. **Repositórios:** 5 repositórios ECR (um por microsserviço), provisionados via Terraform.

> A confirmar: estrutura final dos módulos Terraform (ex.: `modules/networking`, `modules/eks`, `modules/rds`, `modules/elasticache`, `modules/dynamodb`, `modules/sqs`, `modules/ecr`) — documentar aqui a árvore de diretórios real do repositório.

## Backend Remoto do Terraform State

O `terraform.tfstate` não é mantido localmente. O backend remoto está configurado em um **Bucket S3**, com locking de estado habilitado (via `use_lockfile` ou DynamoDB, conforme o mecanismo adotado pelo grupo), evitando aplicações concorrentes e perda de estado entre execuções de diferentes máquinas/pipelines.

## Pipeline de CI & DevSecOps

Cada um dos 5 microsserviços possui seu próprio workflow de CI (GitHub Actions), disparado em Pull Requests e em pushes para a `main`. O pipeline segue os seguintes estágios:

1. **Build & Unit Test:** compilação do código e execução dos testes unitários.
2. **Linter / Static Analysis:** `golangci-lint` para os serviços em Go (`auth-service`, `evaluation-service`) e `pylint`/`flake8` para os serviços em Python (`flag-service`, `targeting-service`, `analytics-service`).
3. **Security Scan (SAST & SCA):**
   - **SCA (Software Composition Analysis):** varredura de vulnerabilidades nas dependências com Trivy (modo `fs`) / OWASP Dependency Check.
   - **SAST (Static Application Security Testing):** análise estática do código-fonte com SonarCloud / `gosec` (Go) e `bandit` (Python).
   - **Regra de bloqueio:** vulnerabilidade classificada como **CRÍTICA** falha o pipeline e impede o prosseguimento para os estágios seguintes.
4. **Docker Build & Push:**
   - Build da imagem Docker do serviço.
   - Container scan de vulnerabilidades na imagem com Trivy.
   - Login no AWS ECR.
   - Push da imagem com a tag do commit hash (ex.: `v1.0.0-a1b2c3d`).

> A confirmar: ferramentas efetivamente escolhidas em cada estágio (Trivy vs. OWASP Dependency Check, SonarCloud vs. gosec/bandit) — ajustar a lista acima para refletir exatamente o que está nos arquivos `.github/workflows/*.yaml` do repositório.

## Entrega Contínua (CD) & GitOps

Abandonamos o push direto de manifests via CI em favor de **GitOps**:

1. **Repositório de GitOps:** os manifestos Kubernetes (YAMLs/Helm Charts) das aplicações vivem separados do código de cada microsserviço, em [repositório/pasta dedicada — informar link].
2. **ArgoCD:** instalado no cluster EKS (via Helm ou Terraform com o provider `helm`/`kubectl`), monitorando o repositório de GitOps.
3. **Atualização automática:** ao final do pipeline de CI, um passo adicional atualiza a tag da imagem no `deployment.yaml` correspondente, no repositório de GitOps, com a tag recém-publicada no ECR.
4. **Sync:** o ArgoCD detecta a mudança no repositório de GitOps e sincroniza automaticamente o cluster EKS, sem intervenção manual — eliminando o `kubectl apply` local que causava os conflitos de versão relatados no desafio.

O ArgoCD passa a gerenciar os 5 microsserviços do ToggleMaster como Applications independentes, cada uma sincronizada a partir do respectivo caminho no repositório de GitOps.

## Dificuldades Encontradas

> A confirmar com o grupo — sugestões de tópicos a documentar, com base no padrão das fases anteriores:
- Restrições de IAM do AWS Academy ao associar a `LabRole` via Terraform (ex.: permissões insuficientes para determinados recursos).
- Falsos positivos ou ruído inicial nos scans de SAST/SCA, exigindo ajuste de thresholds/allowlists.
- Ordenação de dependências no Terraform entre módulos (ex.: EKS depender da VPC, RDS depender das Subnets privadas).
- Sincronização inicial do ArgoCD (ex.: drift entre o estado do cluster criado manualmente na Fase 2 e o novo estado gerenciado via GitOps).

## Estimativa de Custos

![Estimativa de Custos AWS](/.github/estimativa-custos-fase3.png)

> Inserir aqui o print da estimativa de custos da AWS (Cost Explorer ou AWS Pricing Calculator), conforme exigido no relatório de entrega.

## Diagrama de Arquitetura

- Diagrama (SVG): [link do diagrama SVG]

![Diagrama de Arquitetura Fase 3](/.github/DiagramaArquiteturaFase3.png)

## Integrantes do Grupo

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)
- [Maurício Magnago Castro Sá](https://www.linkedin.com/in/mcastrosa)