#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_NAME="healthapi.local"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "WARNING: $1 is not installed. Skipping related cleanup." >&2
    return 1
  fi
  return 0
}

remove_hosts_entry() {
  if ! grep -qE "^[^#]*${HOST_NAME}" /etc/hosts; then
    echo "No hosts entry for ${HOST_NAME} found."
    return
  fi

  echo "Removing ${HOST_NAME} from /etc/hosts..."
  if [[ "$(uname)" == "Darwin" ]]; then
    sudo sed -i '' "/${HOST_NAME}/d" /etc/hosts
  else
    sudo sed -i "/${HOST_NAME}/d" /etc/hosts
  fi
}

stop_minikube_tunnel() {
  if command -v pkill >/dev/null 2>&1; then
    echo "Stopping any running minikube tunnel processes..."
    sudo pkill -f "minikube tunnel" || true
  else
    echo "pkill not available; please stop 'minikube tunnel' manually if needed."
  fi
}

delete_k8s_resources() {
  if require_command kubectl; then
    echo "Deleting Kubernetes manifests..."
    kubectl delete -f "${ROOT}/k8s/service.yaml" --ignore-not-found
    kubectl delete -f "${ROOT}/k8s/deployment.yaml" --ignore-not-found
    kubectl delete -f "${ROOT}/k8s/ingress.yaml" --ignore-not-found
  fi
}

delete_helm_release() {
  if require_command helm; then
    echo "Uninstalling Helm release..."
    helm uninstall healthapi --namespace default || true
  fi
}

delete_minikube() {
  if require_command minikube; then
    echo "Deleting all Minikube profiles and clusters..."
    minikube delete --all || true
  fi
}

delete_docker_image() {
  if require_command docker; then
    echo "Removing local Docker image healthapi:1.0..."
    docker image rm healthapi:1.0 || true
  fi
}

main() {
  delete_helm_release
  delete_k8s_resources
  stop_minikube_tunnel
  delete_minikube
  remove_hosts_entry
  delete_docker_image

  echo
  echo "Cleanup complete."
}

main "$@"
