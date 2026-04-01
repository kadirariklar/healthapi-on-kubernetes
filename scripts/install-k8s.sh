#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="healthapi:1.0"
HOST_NAME="healthapi.local"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: $1 is required but not installed." >&2
    exit 1
  fi
}

ensure_hosts_entry() {
  if grep -qE "^[^#]*${HOST_NAME}" /etc/hosts; then
    echo "Hosts entry for ${HOST_NAME} already exists."
    return
  fi

  echo "Adding ${HOST_NAME} to /etc/hosts..."
  sudo sh -c "echo '127.0.0.1 ${HOST_NAME}' >> /etc/hosts"
}

minikube_start() {
  echo "Starting Minikube with Docker driver and 2 nodes..."
  minikube start --driver=docker --nodes=2
}

build_and_load_image() {
  echo "Building Docker image ${IMAGE_NAME}..."
  docker build -t "${IMAGE_NAME}" "${ROOT}/HealthApi"

  echo "Loading image into Minikube..."
  minikube image load "${IMAGE_NAME}"
}

wait_for_ingress_controller() {
  echo "Waiting for ingress-nginx controller deployment to become available..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Available deployment/ingress-nginx-controller \
    --timeout=300s

  echo "Waiting for ingress-nginx controller pod to become Ready..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod -l app.kubernetes.io/component=controller \
    --timeout=300s

  echo "Giving the admission webhook a few extra seconds to stabilize..."
  sleep 20
}

start_minikube_tunnel() {
  if pgrep -f "minikube tunnel" >/dev/null 2>&1; then
    echo "minikube tunnel already running."
    return
  fi

  echo "Starting minikube tunnel in the background..."
  sudo nohup minikube tunnel > /tmp/minikube-tunnel.log 2>&1 &
  sleep 10
}

deploy_manifests() {
  echo "Applying Kubernetes manifests..."
  kubectl apply -f "${ROOT}/k8s/service.yaml"
  kubectl apply -f "${ROOT}/k8s/deployment.yaml"
  kubectl apply -f "${ROOT}/k8s/ingress.yaml"
}

wait_for_ready() {
  echo "Waiting for deployment to become ready..."
  kubectl rollout status deployment/healthapi-deployment --timeout=120s
}

main() {
  require_command docker
  require_command minikube
  require_command kubectl

  minikube_start
  build_and_load_image

  echo "Enabling ingress addon..."
  minikube addons enable ingress
  wait_for_ingress_controller
  start_minikube_tunnel

  ensure_hosts_entry
  deploy_manifests
  wait_for_ready

  echo
  echo "Deployment complete."
  echo "Verify the app with: curl http://${HOST_NAME}/health"
}

main "$@"
