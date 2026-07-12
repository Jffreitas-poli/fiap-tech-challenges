#!/usr/bin/env bash
# Remove todos os manifestos Kubernetes locais da Fase 2, na ordem inversa
# do up.sh, e por fim o namespace. Não afeta o ingress-nginx controller nem
# o operador do KEDA, instalados separadamente via Helm.
#
# Uso: ./down.sh [-y]
#   -y   pula a confirmação interativa

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SKIP_CONFIRM=false
if [[ "${1:-}" == "-y" ]]; then
  SKIP_CONFIRM=true
fi

if [[ "$SKIP_CONFIRM" == false ]]; then
  read -r -p "Isso vai deletar todos os recursos do namespace 'toggle' no contexto atual do kubectl. Continuar? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelado."
    exit 0
  fi
fi

delete() {
  echo "==> kubectl delete -f ${1#"$ROOT_DIR"/} --ignore-not-found"
  kubectl delete -f "$1" --ignore-not-found
}

echo "== Ingress =="
delete "$ROOT_DIR/ingress.yaml"

echo "== analytics-service =="
delete "$ROOT_DIR/analytics-service/k8s/scaledobject.yaml"
delete "$ROOT_DIR/analytics-service/k8s/hpa.yaml"
delete "$ROOT_DIR/analytics-service/k8s/service.yaml"
delete "$ROOT_DIR/analytics-service/k8s/deployment.yaml"
delete "$ROOT_DIR/analytics-service/k8s/kedaauthentication.yaml"
delete "$ROOT_DIR/analytics-service/k8s/configmap.yaml"

echo "== evaluation-service =="
delete "$ROOT_DIR/evaluation-service/k8s/hpa.yaml"
delete "$ROOT_DIR/evaluation-service/k8s/service.yaml"
delete "$ROOT_DIR/evaluation-service/k8s/deployment.yaml"
delete "$ROOT_DIR/evaluation-service/k8s/configmap.yaml"
delete "$ROOT_DIR/evaluation-service/k8s/secrets.yaml"

echo "== targeting-service =="
delete "$ROOT_DIR/targeting-service/k8s/service.yaml"
delete "$ROOT_DIR/targeting-service/k8s/deployment.yaml"
delete "$ROOT_DIR/targeting-service/k8s/configmap.yaml"
delete "$ROOT_DIR/targeting-service/k8s/secrets.yaml"

echo "== flag-service =="
delete "$ROOT_DIR/flag-service/k8s/service.yaml"
delete "$ROOT_DIR/flag-service/k8s/deployment.yaml"
delete "$ROOT_DIR/flag-service/k8s/configmap.yaml"
delete "$ROOT_DIR/flag-service/k8s/secrets.yaml"

echo "== auth-service =="
delete "$ROOT_DIR/auth-service/k8s/service.yaml"
delete "$ROOT_DIR/auth-service/k8s/deployment.yaml"
delete "$ROOT_DIR/auth-service/k8s/configmap.yaml"
delete "$ROOT_DIR/auth-service/k8s/secrets.yaml"

echo "== Namespace =="
delete "$ROOT_DIR/namespace.yaml"

echo "== Pronto. =="
