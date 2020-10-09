#!/usr/bin/env bash

set -euo pipefail

_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
_image=certs
_output_dir="$_dir/certs"

function build_container() {
  docker build -t "$_image" -f "$_dir/Dockerfile-certs" .
}

function run_container() {
  docker run --rm \
    -v "$_output_dir":/certs \
    "$_image" \
    "$@"
}

echo "Re-creating output dir ..."
rm -rf "$_output_dir"
mkdir -p "$_output_dir"/{proxy,backend}
chmod -R 777 "$_output_dir"

echo "Building container ..."
build_container

echo "Generating certificates ..."

# Generate a CA.
run_container mkcert

# Proxy keypair.
run_container mkcert \
  -cert-file=./proxy/crt.pem \
  -key-file=./proxy/key.pem \
  proxy localhost

# Backend keypair.
run_container mkcert \
  -cert-file=./backend/crt.pem \
  -key-file=./backend/key.pem \
  backend localhost

run_container find /certs -name '*.pem' -exec chmod 0644 {} \;
