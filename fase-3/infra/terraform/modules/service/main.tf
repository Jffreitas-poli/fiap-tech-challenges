########################################################################
# modulo service
# Provisiona UM microsservico do Toggle Master a partir da sua entrada em
# fase-3/services.yaml. Todo recurso e condicional as flags do spec -- e o
# que permite os 5 servicos sairem de um unico for_each no root, sem
# arquivo .tf por servico.
#
# Composicao, nao reimplementacao: os recursos vem dos modulos rds/ecr/sqs/
# dynamodb ja em producao. Reescrever os resources aqui mudaria argumentos
# sutis e o plan viraria update/replace de recurso vivo. Compondo, o unico
# delta do refactor sao os `moved` blocks dos roots.
#
# O que este modulo deliberadamente NAO faz:
#
#  - ElastiCache: e um recurso compartilhado do cluster (so evaluation usa,
#    mas o SG e o subnet group sao do ambiente), fica no root.
#
#  - ServiceAccount do Kubernetes: os namespaces 'toggle' e 'keda' pertencem
#    ao ArgoCD e ao Helm de modules/addons. Criar SA daqui brigaria com o
#    selfHeal do ArgoCD e com o chart do KEDA, que ja cria a sua. O modulo
#    entrega a IAM role e a anotacao pronta -- ver output
#    keda_irsa_annotation -- para o overlay consumir.
########################################################################

locals {
  # Nomes com sufixo de ambiente. O ECR fica FORA disso de proposito: lab e
  # prod sao contas distintas, o nome do repositorio ja e isolado pela conta,
  # e os overlays do GitOps referenciam 'tech-challenge/<svc>-image' cru.
  rds_identifier = "${var.name_prefix}-rds-${var.spec.name}${var.name_suffix}"
  queue_name     = var.spec.queue.enabled ? "${var.spec.queue.name}${var.name_suffix}" : null
  table_name     = var.spec.dynamodb.enabled ? "${var.spec.dynamodb.table}${var.name_suffix}" : null

  # Todo servico tem a imagem da aplicacao. 'dedicated' ganha a segunda
  # (golang-migrate + migrations/); 'app' roda a migration a partir da
  # propria imagem da aplicacao e nao precisa de repositorio extra.
  # Este e o par que sustenta o invariante "nº de repos == SVC_COUNT + MIG".
  ecr_repositories = concat(
    ["tech-challenge/${var.spec.name}-image"],
    var.spec.db.migrate == "dedicated" ? ["tech-challenge/${var.spec.name}-migrate-image"] : [],
  )

  # A fila e UMA so, compartilhada: evaluation produz, analytics consome --
  # os dois trazem queue.enabled = true apontando para o mesmo queue.name.
  # Quem a DECLARA e o consumidor. Se os dois declarassem, seriam dois
  # aws_sqs_queue disputando o nome 'tc-sqs' e o apply falharia.
  create_queue = var.spec.queue.enabled && var.spec.queue.mode == "consumer"

  # ARN montado, nao lido do recurso: o produtor precisa do ARN na policy mas
  # NAO e dono da fila. Referenciar module.sqs do consumidor daqui criaria
  # ciclo dentro do for_each do root.
  queue_arn = var.spec.queue.enabled ? "arn:aws:sqs:${var.region}:${var.account_id}:${local.queue_name}" : null

  create_keda_iam = var.create_iam_role && var.spec.queue.enabled && var.spec.queue.keda

  # host do issuer sem o esquema -- e a forma que a condition do IRSA exige
  oidc_issuer_host = var.oidc_issuer_url == null ? null : replace(var.oidc_issuer_url, "https://", "")
}

########################################################################
# ECR -- sempre (todo servico publica pelo menos uma imagem)
#
# AVISO: ecr_force_delete = true permite ao Terraform apagar um repositorio
# COM imagens dentro. Hoje cada repositorio guarda exatamente a imagem que o
# pod correspondente esta rodando. Nenhum plan deste modulo pode sair com
# destroy/replace de aws_ecr_repository sem decisao explicita.
########################################################################

module "ecr" {
  source = "../ecr"

  repositories         = local.ecr_repositories
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push
  keep_last            = var.ecr_keep_last
  force_delete         = var.ecr_force_delete
}

########################################################################
# RDS PostgreSQL -- database-per-service (db.enabled)
########################################################################

module "rds" {
  source = "../rds"
  count  = var.spec.db.enabled ? 1 : 0

  identifier                  = local.rds_identifier
  db_name                     = var.spec.db.name
  username                    = "postgres"
  instance_class              = var.rds_instance_class
  db_subnet_group_name        = var.rds_db_subnet_group_name
  vpc_security_group_ids      = var.rds_vpc_security_group_ids
  multi_az                    = var.rds_multi_az
  deletion_protection         = var.rds_deletion_protection
  skip_final_snapshot         = var.rds_skip_final_snapshot
  backup_retention_period     = var.rds_backup_retention_period
  secret_recovery_window_days = var.rds_secret_recovery_window_days
}

########################################################################
# SQS -- fila + DLQ, declarada pelo CONSUMIDOR (ver local.create_queue)
########################################################################

module "sqs" {
  source = "../sqs"
  count  = local.create_queue ? 1 : 0

  name = local.queue_name
}

########################################################################
# DynamoDB (dynamodb.enabled)
########################################################################

module "dynamodb" {
  source = "../dynamodb"
  count  = var.spec.dynamodb.enabled ? 1 : 0

  name                   = local.table_name
  hash_key               = "event_id"
  point_in_time_recovery = var.dynamodb_point_in_time_recovery
}

########################################################################
# IRSA do KEDA -- so quando o servico tem ScaledObject (queue.keda) E o
# ambiente permite criar role (create_iam_role).
#
# Escopo minimo de proposito: o KEDA so precisa LER a profundidade da fila
# para decidir o numero de replicas. Receive/Delete pertencem ao pod da
# aplicacao, que tem a sua propria identidade.
########################################################################

data "aws_iam_policy_document" "keda_sqs" {
  count = local.create_keda_iam ? 1 : 0

  statement {
    sid       = "KedaReadQueueDepth"
    effect    = "Allow"
    actions   = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = [local.queue_arn]
  }
}

resource "aws_iam_policy" "keda_sqs" {
  count = local.create_keda_iam ? 1 : 0

  name        = "${var.name_prefix}-keda-${var.spec.name}${var.name_suffix}"
  description = "Leitura da profundidade da fila ${local.queue_name} pelo KEDA (${var.spec.name})."
  policy      = data.aws_iam_policy_document.keda_sqs[0].json
}

data "aws_iam_policy_document" "keda_trust" {
  count = local.create_keda_iam ? 1 : 0

  statement {
    sid     = "KedaIrsaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${var.keda_namespace}:${var.keda_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "keda" {
  count = local.create_keda_iam ? 1 : 0

  name                 = "${var.name_prefix}-keda-${var.spec.name}${var.name_suffix}-irsa"
  description          = "Role assumida via IRSA pelo operator do KEDA para escalar ${var.spec.name}."
  assume_role_policy   = data.aws_iam_policy_document.keda_trust[0].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "keda" {
  count = local.create_keda_iam ? 1 : 0

  role       = aws_iam_role.keda[0].name
  policy_arn = aws_iam_policy.keda_sqs[0].arn
}
