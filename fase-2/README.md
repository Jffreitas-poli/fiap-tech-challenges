<div align="center">
  <br/>
  <hr style="border: none; border-top: 1px solid #ED145B; width: 100%; margin: 0 auto"/>
</div>

![/.github/LOGO-FIAP.png](/.github/LOGO-FIAP.png)

# Tech Challenge - Objetivos da Fase 2

Evoluímos a aplicação Toggle Master, analisada como monolito na Fase 1, para uma arquitetura de microsserviços containerizada, orquestrada em Kubernetes e preparada para escalabilidade em produção.

## Entregáveis da Fase 2

1. **Vídeo de Demonstração (até 20 minutos):** [Vídeo de Demonstração Tech Challenge Fase 2](https://youtu.be/PQY-z_hbAVU)

2. **Documentação Separada por Tópicos:**

- [Arquitetura de Microsserviços](#arquitetura-de-microsserviços);
- [Conteinerização](#conteinerização);
- [Orquestração com Kubernetes / EKS](#orquestração-com-kubernetes--eks);
- [Persistência de Dados](#persistência-de-dados);
- [Balanceamento de Carga](#balanceamento-de-carga);
- [Escalabilidade Automática](#escalabilidade-automática);
- [Segurança](#segurança);
- [Dificuldades Encontradas](#dificuldades-encontradas);
- [Diagrama de Arquitetura](#diagrama-de-arquitetura);
- [Integrantes do Grupo](#integrantes-do-grupo);
- [Observações do Vídeo e Decisões de Arquitetura](#observações-do-vídeo-e-decisões-de-arquitetura);

3. **Integrantes do Grupo**:

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)
- [Maurício Magnago Castro Sá](https://www.linkedin.com/in/mcastrosa)

## Arquitetura de Microsserviços

O sistema foi decomposto em 5 microsserviços:

| Serviço | Linguagem | Responsabilidade |
|---|---|---|
| `auth-service` | Go | Autenticação e emissão de credenciais |
| `flag-service` | Python | CRUD e definição de feature flags |
| `targeting-service` | Python | Regras de segmentação/targeting |
| `evaluation-service` | Go | Avaliação de flags em tempo de execução |
| `analytics-service` | Python | Coleta e processamento de métricas de uso |

Cada serviço é implantado de forma independente no cluster EKS `tc-eks` (região `us-east-2`), permitindo deploys e escalabilidade isolados por serviço — resolvendo o acoplamento forte identificado na Fase 1.

## Conteinerização

Cada microsserviço possui seu próprio `Dockerfile`, com imagens publicadas em um registro no **ECR (Elastic Container Registry)** da AWS. O fluxo de build e push segue:

1. Build da imagem local/CI.
2. Tag da imagem com o repositório do ECR.
3. Push da imagem para o ECR.
4. Referência da imagem no manifest Kubernetes do serviço correspondente.

Todas as imagens foram validadas localmente antes do deploy: cada serviço possui seu próprio `docker-compose.yaml` para testes isolados, além de um `docker-compose.yaml` consolidado, que sobe todo o ambiente com um único comando. Os manifestos Kubernetes também foram executados localmente (Kind/Minikube) consumindo as imagens já publicadas no ECR, conforme documentado nos scripts de start do repositório — garantindo paridade entre o ambiente local e o cluster EKS antes de ir para produção.

## Orquestração com Kubernetes / EKS

O cluster EKS `tc-eks` foi provisionado com `eksctl`, considerando as restrições de permissões do ambiente AWS Academy/Vocareum (sem acesso completo ao IAM, de forma similar ao que ocorreu na Fase 1).

Componentes principais no cluster:

- **Deployments e Services** para cada um dos 5 microsserviços.
- **NGINX Ingress Controller** como ponto único de entrada.
- Integração com o **ECR** para pull das imagens, com tags imutáveis e versionamento seguindo o padrão [Semantic Versioning](https://semver.org).

## Persistência de Dados

O propósito de cada escolha:

- **RDS PostgreSQL**: usado pelos serviços com dados relacionais, transacionais e com fortes garantias de consistência — `auth-service`, `flag-service` e `targeting-service`. São dados com relacionamento entre entidades (usuários, flags, regras de segmentação) e que exigem integridade referencial e transações ACID. Seguindo o princípio de *database-per-service*, cada serviço possui sua própria instância RDS, evitando acoplamento pelo banco de dados — um dos pontos negativos identificados no monolito da Fase 1 (Fator IV).
- **ElastiCache Serverless (Redis)**: usado como camada de cache e para dados de curtíssima duração (ex.: resultado de avaliação de flags, contadores), onde a prioridade é latência baixíssima em vez de durabilidade. Conexão via TLS (`rediss://`), com acesso restrito por Security Group apenas ao cluster EKS.
- **DynamoDB**: usado pelo `analytics-service` para armazenar eventos de uso e métricas. Esse tipo de dado tem alto volume de escrita, padrão de acesso simples (chave-valor / por partição) e não exige schema rígido nem joins — características em que o DynamoDB escala horizontalmente de forma nativa e sustenta picos de escrita sem o overhead de um banco relacional. Isso também permite que o `analytics-service` escale via KEDA sem gerar contenção em um banco relacional compartilhado.

## Balanceamento de Carga

O **NGINX Ingress Controller** atua como reverse proxy e load balancer, distribuindo o tráfego entre os pods de cada serviço e realizando health checks para failover automático.

## Escalabilidade Automática

Implementamos autoscaling orientado a eventos com **KEDA**, escalando o `analytics-service` com base na profundidade de uma fila **SQS**. A autenticação entre os pods e a AWS é feita via **IRSA (IAM Roles for Service Accounts)**, evitando credenciais estáticas nos containers.

## Segurança

- Regras de **Security Group** restringindo o acesso ao Redis e ao RDS apenas ao cluster EKS.
- Uso de **IRSA** para autenticação do `analytics-service` com a fila SQS e com o DynamoDB, sem chaves de acesso fixas.

## Dificuldades Encontradas

- **Controle de custo:** para evitar consumo desnecessário de recursos AWS durante o desenvolvimento, adotamos a estratégia de provisionar todas as dependências, validar a integração e rodar os primeiros testes consumindo `localhost`, subindo os recursos gerenciados na nuvem apenas quando o fluxo já estava estável.
- **Dependências não utilizadas:** identificamos bibliotecas declaradas nos projetos que não eram efetivamente usadas em nenhum ponto do código, e removemos para reduzir a superfície de imagem e o tempo de build.
- **Bibliotecas depreciadas ou inexistentes:** algumas dependências listadas estavam depreciadas ou não existiam mais nos registros públicos, exigindo substituição por alternativas mantidas.
- **Ausência de migrations:** os scripts de banco de dados originais não utilizavam controle de migrations. Criamos as classes de migration necessárias para versionar e aplicar as alterações de schema de forma reprodutível em cada instância RDS.

## Diagrama de Arquitetura


![Diagrama de Arquitetura Fase 2](/.github/toggle-master-arquitetura-distribuida.svg
)

## Integrantes do Grupo

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)
- [Maurício Magnago Castro Sá](https://www.linkedin.com/in/mcastrosa)

## Observações do Vídeo e Decisões de Arquitetura

> ⚠️ **Atenção:** este bloco reforça, por escrito, alguns pontos comentados no vídeo, para que fiquem registrados também na documentação.

**Sobre a afirmação de que o KEDA é "superior":**
No vídeo, quando dizemos que o KEDA é superior, a comparação é especificamente em relação a um HPA tradicional baseado em CPU/memória, e no contexto do `analytics-service`. O KEDA escala os pods com base no tamanho da fila SQS — ou seja, na demanda real de processamento — e não em métricas indiretas de uso de máquina. Isso permite zerar as réplicas quando a fila está vazia e escalar rapidamente quando o volume de eventos aumenta, otimizando o uso de recursos (e, por consequência, o custo) sem sacrificar a capacidade de resposta em picos de carga.

**Defesa da escolha de um único Ingress:**
Optamos por um único NGINX Ingress Controller como porta de entrada para todos os microsserviços, em vez de um Ingress por serviço.

*Pontos positivos:*
- **Menor custo de infraestrutura:** um único Load Balancer (ALB/NLB) provisionado, em vez de um por serviço.
- **Ponto único de observabilidade:** logs, métricas e health checks de borda centralizados, facilitando troubleshooting.
- **Gestão simplificada de TLS/certificados:** um único lugar para configurar certificado e políticas de segurança de borda (rate limiting, headers, etc.), aplicado de forma consistente a todos os serviços.
- **Roteamento centralizado:** regras de path/host ficam em um único recurso, facilitando versionamento e auditoria das rotas expostas publicamente.

*Trade-offs:*
- **Ponto único de falha:** se o Ingress Controller cair, todos os serviços ficam inacessíveis externamente ao mesmo tempo — mitigado rodando múltiplas réplicas do controller.
- **Acoplamento de configuração:** uma mudança malfeita nas regras de roteamento de um serviço pode, em tese, impactar a disponibilidade de rotas de outro serviço, exigindo cuidado (e idealmente CI/validação) nas alterações do manifesto de Ingress.
- **Escalabilidade do próprio Ingress:** como ele concentra todo o tráfego de entrada, precisa ser dimensionado (réplicas/HPA) para não virar gargalo, diferente de um cenário com Ingress dedicado por serviço, onde o tráfego de borda já nasce naturalmente particionado.

Para o estágio atual do projeto, avaliamos que os ganhos de custo, simplicidade operacional e observabilidade centralizada superam esses trade-offs, principalmente por já mitigarmos o ponto único de falha com múltiplas réplicas do controller.

*Estratégia de mitigação — múltiplas réplicas do controller:*

O recurso `Ingress` versionado em [`fase-2/ingress.yaml`](./ingress.yaml) apenas declara as regras de roteamento; quem efetivamente processa o tráfego é o **NGINX Ingress Controller**, instalado no cluster via Helm chart (`ingress-nginx`), e não como manifesto cru neste repositório. Os valores de Helm usados para configurá-lo estão versionados em [`fase-2/ingress-nginx-values.yaml`](./ingress-nginx-values.yaml) e cobrem:

- **`replicaCount: 2`**: baseline de duas réplicas do controller, eliminando o ponto único de falha a nível de pod.
- **`autoscaling` (2 a 5 réplicas, 70% CPU)**: garante capacidade extra em picos de tráfego, evitando que o Ingress vire gargalo mesmo concentrando toda a entrada do cluster.
- **`podAntiAffinity` + `topologySpreadConstraints`**: distribui as réplicas em nodes e AZs diferentes, para que a perda de um node (ou de uma AZ inteira) não derrube todas as réplicas do controller ao mesmo tempo.
- **`podDisruptionBudget` (`minAvailable: 1`)**: garante que operações de manutenção do cluster (ex.: rotação de nodes, upgrades) não removam todas as réplicas simultaneamente.

Aplicação:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f fase-2/ingress-nginx-values.yaml
```

Com isso, o principal risco do "Ingress único" (ponto único de falha) fica mitigado sem abrir mão dos ganhos de custo e simplicidade operacional da abordagem centralizada.
