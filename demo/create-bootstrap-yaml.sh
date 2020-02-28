#!/bin/bash

set -aueo pipefail

# shellcheck disable=SC1091
source .env


CONFIG_DIR="./config/${K8S_NAMESPACE}"

mkdir -p "$CONFIG_DIR"

FILE="$CONFIG_DIR/bootstrap.yaml"

echo "Creating $FILE"

cat <<EOF > "$FILE"
admin:
  access_log_path: "/dev/stdout"
  address:
    socket_address: {address: 0.0.0.0, port_value: 15000}

dynamic_resources:
  ads_config:
    api_type: GRPC
    grpc_services:
    - envoy_grpc:
        cluster_name: ads
    set_node_on_first_message_only: true
  cds_config:
    ads: {}
  lds_config:
    ads: {}

static_resources:
  clusters:

  - name: ads
    connect_timeout: 0.25s
    type: LOGICAL_DNS
    http2_protocol_options: {}
    tls_context:
      common_tls_context:
        tls_params:
          tls_minimum_protocol_version: TLSv1_2
          tls_maximum_protocol_version: TLSv1_3
          cipher_suites: "[ECDHE-ECDSA-AES128-GCM-SHA256|ECDHE-ECDSA-CHACHA20-POLY1305]"
        tls_certificates:
          - certificate_chain: { filename: "/etc/ssl/certs/cert.pem" }
            private_key: { filename: "/etc/ssl/certs/key.pem" }
    load_assignment:
      cluster_name: ads
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: ads.${K8S_NAMESPACE}.svc.cluster.local
                port_value: 15128
EOF

rm -rf "${CONFIG_DIR}/*~"
rm -rf "${CONFIG_DIR}/*\\#*"

kubectl delete configmap envoyproxy-config -n "$K8S_NAMESPACE" || true
kubectl create \
        configmap envoyproxy-config \
        --from-file="${CONFIG_DIR}" \
        -n "$K8S_NAMESPACE" || true