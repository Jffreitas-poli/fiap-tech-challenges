variable "name" {
  description = "Nome da fila principal (ex.: tc-sqs). A DLQ sera <name>-dlq."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout da fila principal. >= tempo de processamento do analytics-service."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "Retencao de mensagens na fila principal."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Retencao de mensagens na DLQ."
  type        = number
  default     = 1209600
}

variable "max_receive_count" {
  description = "Tentativas antes de mover a mensagem para a DLQ."
  type        = number
  default     = 5
}

variable "receive_wait_time_seconds" {
  description = "Long polling (segundos)."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}
