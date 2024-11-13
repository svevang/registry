#!/bin/sh
docker run -d \
  --name registry \
  --restart=always \
  -p 192.168.1.108:5000:5000 \
  -v $(pwd)/registry-data:/var/lib/registry \
  -v $(pwd)/config.yml:/etc/distribution/config.yml \
  -v $(pwd)/certs:/certs:ro \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  registry:2
