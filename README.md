# Private Docker Registry Setup Guide

This guide walks through setting up a private Docker registry with self-signed SSL certificates.

## Prerequisites

- Docker installed
- OpenSSL installed
- Root/sudo access
- Docker registry running at registry.blotzy.com:5000

## 1. Generate SSL Certificates

First, create the certificates directory and generate the self-signed certificate:

```bash
# Create directory for certs
mkdir -p certs

# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -days 365 -nodes \
  -keyout certs/domain.key \
  -out certs/domain.crt \
  -subj "/CN=registry.blotzy.com" \
  -addext "subjectAltName = DNS:registry.blotzy.com,IP:192.168.1.108"
```

## 2. Configure Registry

Create or update your registry's configuration file (`config.yml`):

```yaml
version: 0.1
log:
  level: debug
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
    minimumTLS: tls1.2
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

## 3. Start Registry Container

Stop any existing registry container and start a new one with SSL support:

```bash
# Stop and remove existing registry
docker stop registry
docker rm registry

# Start new registry with SSL support
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
```

## 4. Install Certificates on Docker Host

Install the certificates on the machine running Docker:

```bash
# Create certificate directories
sudo mkdir -p /etc/docker/certs.d/registry.blotzy.com:5000
sudo mkdir -p /etc/docker/certs.d/192.168.1.108:5000

# Copy certificates
sudo cp certs/domain.crt /etc/docker/certs.d/registry.blotzy.com:5000/ca.crt
sudo cp certs/domain.crt /etc/docker/certs.d/192.168.1.108:5000/ca.crt

# For Ubuntu/Debian systems, add to system CA store
sudo cp certs/domain.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Restart Docker daemon
sudo systemctl restart docker
```

## 5. Configure Minikube

Install certificates in Minikube and restart the service:

```bash
# Copy cert to minikube
minikube cp certs/domain.crt /usr/local/share/ca-certificates/registry-cert.crt

# Update certificates inside minikube
minikube ssh "sudo update-ca-certificates"

# Restart minikube
minikube stop
minikube start
```

## 6. Update Host Resolution

Add registry hostname to /etc/hosts if not using DNS:

```bash
# Add to /etc/hosts
sudo bash -c 'echo "192.168.1.108 registry.blotzy.com" >> /etc/hosts'
```

## 7. Verify Setup

Test the registry connection:

```bash
# Test with curl
curl -v --cacert certs/domain.crt https://registry.blotzy.com:5000/v2/_catalog

# Test with Docker
docker pull hello-world
docker tag hello-world registry.blotzy.com:5000/hello-world
docker push registry.blotzy.com:5000/hello-world
```

## Maintenance Notes

### Certificate Renewal

Certificates will expire after 365 days. Set a reminder to renew them before expiration:

```bash
# Check certificate expiration
openssl x509 -in certs/domain.crt -noout -enddate
```

### Troubleshooting

If you encounter issues:

1. Check registry logs:
```bash
docker logs registry
```

2. Verify certificate installation:
```bash
openssl x509 -in certs/domain.crt -text -noout
```

3. Test registry connection:
```bash
curl -v --cacert certs/domain.crt https://registry.blotzy.com:5000/v2/_catalog
```

4. Check Docker daemon logs:
```bash
journalctl -u docker.service
```
