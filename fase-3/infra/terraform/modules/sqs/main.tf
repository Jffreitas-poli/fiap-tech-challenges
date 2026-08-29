########################################################################
# modulo sqs
# Fila Standard + DLQ com redrive. evaluation-service produz, analytics-
# service consome, e o KEDA usa a profundidade da fila como trigger.
#
# Nota Academy: NAO ha aws_iam_policy/role aqui. O acesso a fila e
# concedido pela LabRole (role de instancia dos nodes EKS). Em conta AWS
# real, criar policy sqs:{ReceiveMessage,DeleteMessage,GetQueueAttributes}
# e associar via IRSA (ver modulo iam_oidc_github).
########################################################################

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds

  tags = merge(var.tags, { Name = "${var.name}-dlq" })
}

resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}
