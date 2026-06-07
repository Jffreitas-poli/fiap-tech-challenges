#!/bin/bash
set -e

ENDPOINT=http://localhost:4566
REGION=us-east-1

echo ">>> Criando fila SQS: analytics-queue"
awslocal sqs create-queue \
  --queue-name analytics-queue \
  --region $REGION

echo ">>> Criando tabela DynamoDB: ToggleMasterAnalytics"
awslocal dynamodb create-table \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=event_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION

echo ">>> Recursos criados com sucesso"
