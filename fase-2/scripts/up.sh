#!/usr/bin/env bash
# Sobe todos os manifestos Kubernetes locais da Fase 2 (namespace, secrets,
# configmaps, deployments, services, HPA, KEDA e ingress), na ordem correta
# de dependência. Pressupõe um cluster local (Kind/Minikube) já ativo, com
# o ingress-nginx controller e o operador do KEDA instalados previamente.
#
# Uso: ./up.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

apply() {
  echo "==> kubectl apply -f ${1#"$ROOT_DIR"/}"
  kubectl apply -f "$1"
}

echo "== Namespace =="
apply "$ROOT_DIR/namespace.yaml"

echo "== auth-service =="
apply "$ROOT_DIR/auth-service/k8s/secrets.yaml"
apply "$ROOT_DIR/auth-service/k8s/configmap.yaml"
apply "$ROOT_DIR/auth-service/k8s/deployment.yaml"
apply "$ROOT_DIR/auth-service/k8s/service.yaml"

echo "== flag-service =="
apply "$ROOT_DIR/flag-service/k8s/secrets.yaml"
apply "$ROOT_DIR/flag-service/k8s/configmap.yaml"
apply "$ROOT_DIR/flag-service/k8s/deployment.yaml"
apply "$ROOT_DIR/flag-service/k8s/service.yaml"

echo "== targeting-service =="
apply "$ROOT_DIR/targeting-service/k8s/secrets.yaml"
apply "$ROOT_DIR/targeting-service/k8s/configmap.yaml"
apply "$ROOT_DIR/targeting-service/k8s/deployment.yaml"
apply "$ROOT_DIR/targeting-service/k8s/service.yaml"

echo "== evaluation-service =="
apply "$ROOT_DIR/evaluation-service/k8s/secrets.yaml"
apply "$ROOT_DIR/evaluation-service/k8s/configmap.yaml"
apply "$ROOT_DIR/evaluation-service/k8s/deployment.yaml"
apply "$ROOT_DIR/evaluation-service/k8s/service.yaml"
apply "$ROOT_DIR/evaluation-service/k8s/hpa.yaml"

echo "== analytics-service =="
apply "$ROOT_DIR/analytics-service/k8s/configmap.yaml"
apply "$ROOT_DIR/analytics-service/k8s/kedaauthentication.yaml"
apply "$ROOT_DIR/analytics-service/k8s/deployment.yaml"
apply "$ROOT_DIR/analytics-service/k8s/service.yaml"
apply "$ROOT_DIR/analytics-service/k8s/hpa.yaml"
apply "$ROOT_DIR/analytics-service/k8s/scaledobject.yaml"

echo "== Ingress =="
apply "$ROOT_DIR/ingress.yaml"

echo "== Pronto. Acompanhe os pods com: kubectl get pods -n toggle -w =="
