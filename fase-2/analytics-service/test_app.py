"""Smoke test do analytics-service.

app.py exige AWS_REGION / AWS_SQS_URL / AWS_DYNAMODB_TABLE (senao sys.exit(1)),
cria clientes boto3 e sobe o worker SQS numa thread ao ser importado -> definimos
o env, mockamos boto3.Session e neutralizamos threading.Thread antes do import.
A rota /health nao toca AWS.
"""

import importlib
import os
from unittest import mock

os.environ.setdefault("AWS_REGION", "us-east-1")
os.environ.setdefault("AWS_SQS_URL", "https://sqs.us-east-1.amazonaws.com/000/tc-sqs")
os.environ.setdefault("AWS_DYNAMODB_TABLE", "tc-dynamo")

with mock.patch("boto3.Session"), mock.patch("threading.Thread"):
    app_module = importlib.import_module("app")

client = app_module.app.test_client()


def test_health_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}
