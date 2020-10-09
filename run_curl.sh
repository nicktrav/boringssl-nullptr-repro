#!/usr/bin/env bash

set -eo pipefail

exec curl \
  -v \
  -x https://localhost:4433 \
  --proxy-cacert /etc/tls/ca.pem \
  --cacert /etc/tls/ca.pem \
  https://localhost:4444
