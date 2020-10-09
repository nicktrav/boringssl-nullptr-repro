#!/usr/bin/env bash

set -exuo pipefail

_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

_boringssl_version=${BORINGSSL_VERSION:-a673d0245}
_curl_version=${CURL_VERSION:-1101fbbf4}
_skip_certs=${SKIP_CERTS:-false}

echo "Building images ..."

export DOCKER_BUILDKIT=1

docker build -t backend -f "$_dir/Dockerfile-backend" .

docker build \
  --build-arg BORINGSSL_VERSION="$_boringssl_version" \
  --build-arg CURL_VERSION="$_curl_version" \
  -t curl \
  -f "$_dir/Dockerfile-curl" \
  .

echo "Generating TLS certificates ..."
if [[ ! $_skip_certs == 'true' ]]; then
  "$_dir"/generate_certs.sh
fi

echo "Starting backend ..."
_backend=$(docker run -d --rm --network host \
  -v "$_dir"/certs/backend:/etc/tls \
  backend \
    -addr :4444 \
    -cert /etc/tls/crt.pem \
    -key /etc/tls/key.pem)

echo "Starting proxy ..."
_proxy=$(docker run -d --rm --network host \
  -v "$_dir"/certs/proxy:/etc/tls \
  -v "$_dir"/envoy.yaml:/etc/envoy/config.yaml \
  envoyproxy/envoy:v1.16.0 -c /etc/envoy/config.yaml)

function cleanup() {
  echo "Cleaning up ..."
  docker kill "$_backend"
  docker kill "$_proxy"
}
trap cleanup EXIT

echo "Running test container ..."
docker run --rm -it --network host \
  -v "$_dir"/certs/rootCA.pem:/etc/tls/ca.pem \
  -v "$_dir"/run_curl.sh:/run_curl.sh \
  curl
