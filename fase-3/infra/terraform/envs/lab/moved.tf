########################################################################
# Migracao de endereco -- refactor para modules/service
#
# LEIA ANTES DE MEXER.
#
# Os recursos abaixo JA EXISTEM e estao em producao. O refactor que moveu
# RDS/SQS/DynamoDB/ECR para dentro de modules/service mudou o ENDERECO deles
# no state, nao a sua configuracao. Sem estes blocos o Terraform nao
# reconhece a equivalencia e planeja destroy + create de cada um:
#
#   - os 6 repositorios ECR guardam hoje exatamente 1 imagem cada, e e a
#     imagem que o pod correspondente esta rodando (newTag nos overlays do
#     GitOps). O modulo ECR usa force_delete = true, entao a AWS NAO barra o
#     destroy: o repositorio some com a imagem dentro e o pod nao reinicia;
#   - as 3 instancias RDS tem skip_final_snapshot = true no lab: destroy e
#     perda de dados sem snapshot.
#
# `moved` e declarativo, versionado e aparece no plan como "moved" (zero
# destroy) -- por isso e usado aqui em vez de `terraform state mv`, que seria
# imperativo, fora do git e nao reproduzivel no CI.
#
# Este arquivo e IDENTICO em envs/lab e envs/prod: enderecos de Terraform nao
# dependem do ambiente. Em prod, cujo state esta vazio, os blocos sao no-op.
#
# So podem ser removidos depois que TODOS os ambientes tiverem aplicado o
# refactor. Removidos antes, o proximo apply volta a planejar destroy.
########################################################################

########################################################################
# RDS -- move o modulo inteiro (instancia, senha, secret e versao do secret)
########################################################################

moved {
  from = module.rds["auth"]
  to   = module.service["auth"].module.rds[0]
}

moved {
  from = module.rds["flag"]
  to   = module.service["flag"].module.rds[0]
}

moved {
  from = module.rds["targeting"]
  to   = module.service["targeting"].module.rds[0]
}

########################################################################
# SQS e DynamoDB -- pertencem ao consumidor da fila (analytics)
########################################################################

moved {
  from = module.sqs
  to   = module.service["analytics"].module.sqs[0]
}

moved {
  from = module.dynamodb
  to   = module.service["analytics"].module.dynamodb[0]
}

########################################################################
# ECR -- o antigo module.ecr era UMA chamada com os 6 repositorios; agora
# cada servico traz o(s) seu(s). Nao da para mover o modulo inteiro: as
# chaves precisam ser reatribuidas uma a uma ao servico dono.
#
# auth tem 2 repositorios porque db.migrate = dedicated (golang-migrate).
# flag e targeting rodam Alembic a partir da imagem da aplicacao.
########################################################################

moved {
  from = module.ecr.aws_ecr_repository.this["tech-challenge/auth-image"]
  to   = module.service["auth"].module.ecr.aws_ecr_repository.this["tech-challenge/auth-image"]
}

moved {
  from = module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/auth-image"]
  to   = module.service["auth"].module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/auth-image"]
}

moved {
  from = module.ecr.aws_ecr_repository.this["tech-challenge/auth-migrate-image"]
  to   = module.service["auth"].module.ecr.aws_ecr_repository.this["tech-challenge/auth-migrate-image"]
}

moved {
  from = module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/auth-migrate-image"]
  to   = module.service["auth"].module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/auth-migrate-image"]
}

moved {
  from = module.ecr.aws_ecr_repository.this["tech-challenge/flag-image"]
  to   = module.service["flag"].module.ecr.aws_ecr_repository.this["tech-challenge/flag-image"]
}

moved {
  from = module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/flag-image"]
  to   = module.service["flag"].module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/flag-image"]
}

moved {
  from = module.ecr.aws_ecr_repository.this["tech-challenge/targeting-image"]
  to   = module.service["targeting"].module.ecr.aws_ecr_repository.this["tech-challenge/targeting-image"]
}

moved {
  from = module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/targeting-image"]
  to   = module.service["targeting"].module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/targeting-image"]
}

moved {
  from = module.ecr.aws_ecr_repository.this["tech-challenge/evaluation-image"]
  to   = module.service["evaluation"].module.ecr.aws_ecr_repository.this["tech-challenge/evaluation-image"]
}

moved {
  from = module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/evaluation-image"]
  to   = module.service["evaluation"].module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/evaluation-image"]
}

moved {
  from = module.ecr.aws_ecr_repository.this["tech-challenge/analytics-image"]
  to   = module.service["analytics"].module.ecr.aws_ecr_repository.this["tech-challenge/analytics-image"]
}

moved {
  from = module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/analytics-image"]
  to   = module.service["analytics"].module.ecr.aws_ecr_lifecycle_policy.this["tech-challenge/analytics-image"]
}
