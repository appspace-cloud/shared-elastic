# Deployment Guide

This guide provides step-by-step instructions for deploying the Shared Elastic cluster using this Helm chart.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation-steps)
3. [Configuration](#configuration)
4. [Verification](#verification)
5. [Post-Installation](#post-installation)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before deploying, ensure you have:

### Required Software

- **Kubernetes Cluster**: Version 1.21 or higher
  - Minimum 3 worker nodes recommended for production
  - Ensure nodes have sufficient resources (see resource requirements below)

- **Helm**: Version 3.0 or higher
  ```bash
  helm version
  ```

- **kubectl**: Configured to access your cluster
  ```bash
  kubectl cluster-info
  ```

### Resource Requirements

#### Minimum Requirements (Development)
- 1 node with 4 CPU cores and 8GB RAM
- 20GB storage

#### Recommended Requirements (Production)
- 8+ nodes
- Master nodes: 3 x (2 CPU, 4GB RAM, 20GB storage)
- Data nodes: 5 x (4 CPU, 8GB RAM, 500GB storage)
- Coordinating nodes: 3 x (2 CPU, 4GB RAM, 20GB storage)

### ECK Operator

The ECK (Elastic Cloud on Kubernetes) operator must be installed:

```bash
# Install CRDs
kubectl create -f https://download.elastic.co/downloads/eck/2.11.0/crds.yaml

# Install operator
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.0/operator.yaml

# Verify installation
kubectl get pods -n elastic-system
```

Expected output:
```
NAME                 READY   STATUS    RESTARTS   AGE
elastic-operator-0   1/1     Running   0          1m
```

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/appspace-cloud/shared-elastic.git
cd shared-elastic
```

### Step 2: Review Configuration

Choose an appropriate values file or customize the default:

- `chart/values.yaml` - Default production configuration
- `chart/examples/values-minimal.yaml` - Minimal single-node setup
- `chart/examples/values-dev.yaml` - Development environment
- `chart/examples/values-production.yaml` - Production with high availability

### Step 3: Create Namespace

```bash
kubectl create namespace elasticsearch
```

### Step 4: Install the Chart

#### Option A: Default Configuration

```bash
helm install shared-elastic ./chart --namespace elasticsearch
```

#### Option B: Custom Configuration

```bash
# Using an example values file
helm install shared-elastic ./chart \
  --namespace elasticsearch \
  -f chart/examples/values-production.yaml
```

#### Option C: Override Specific Values

```bash
helm install shared-elastic ./chart \
  --namespace elasticsearch \
  --set appspace.elastic.name=my-cluster \
  --set appspace.elastic.version=8.15.1 \
  --set appspace.elastic.nodeSets[0].count=5
```

### Step 5: Wait for Deployment

```bash
# Watch the Elasticsearch resource
kubectl get elasticsearch -n elasticsearch -w

# Watch pods
kubectl get pods -n elasticsearch -w
```

The deployment is complete when the Elasticsearch resource shows phase `Ready` and health `green`:

```
NAME             HEALTH   NODES   VERSION   PHASE   AGE
shared-elastic   green    8       8.15.1    Ready   5m
```

## Configuration

### Common Customizations

#### Change Cluster Name

```bash
helm install shared-elastic ./chart \
  --namespace elasticsearch \
  --set appspace.elastic.name=production-cluster
```

#### Adjust Node Counts

```bash
helm install shared-elastic ./chart \
  --namespace elasticsearch \
  --set appspace.elastic.nodeSets[0].count=5 \
  --set appspace.elastic.nodeSets[1].count=10
```

#### Configure Storage

Create a custom values file (`custom-values.yaml`):

```yaml
appspace:
  elastic:
    nodeSets:
      - name: master
        count: 3
        volumeClaimTemplates:
          - metadata:
              name: elasticsearch-data
            spec:
              storageClassName: fast-ssd
              resources:
                requests:
                  storage: 50Gi
```

Apply:
```bash
helm install shared-elastic ./chart \
  --namespace elasticsearch \
  -f custom-values.yaml
```

## Verification

### 1. Check Cluster Status

```bash
kubectl get elasticsearch shared-elastic -n elasticsearch
```

Expected output:
```
NAME             HEALTH   NODES   VERSION   PHASE   AGE
shared-elastic   green    8       8.15.1    Ready   10m
```

### 2. Check Pods

```bash
kubectl get pods -n elasticsearch
```

All pods should be in `Running` state with `1/1` ready.

### 3. Check Services

```bash
kubectl get svc -n elasticsearch
```

You should see the Elasticsearch HTTP and transport services.

### 4. Test Cluster Health

```bash
# Get password
PASSWORD=$(kubectl get secret shared-elastic-es-elastic-user \
  -n elasticsearch \
  -o go-template='{{.data.elastic | base64decode}}')

# Port forward
kubectl port-forward -n elasticsearch service/shared-elastic-es-http 9200:9200 &

# Test cluster
curl -k -u "elastic:$PASSWORD" https://localhost:9200/_cluster/health?pretty
```

Expected output shows:
- `"status": "green"`
- `"number_of_nodes"` matches your configuration

## Post-Installation

### 1. Save Credentials

Store the elastic user password securely:

```bash
kubectl get secret shared-elastic-es-elastic-user \
  -n elasticsearch \
  -o go-template='{{.data.elastic | base64decode}}' > elastic-password.txt
```

⚠️ **Security Note**: Store this file securely and don't commit it to version control!

### 2. Configure Monitoring (Optional)

If you have a monitoring cluster, enable monitoring:

```yaml
appspace:
  elastic:
    monitoring:
      enabled: true
      metrics:
        elasticsearchRefs:
          - name: monitoring-cluster
            namespace: monitoring
```

### 3. Set Up Backups

Configure snapshot repository for backups. Example for S3:

```yaml
appspace:
  elastic:
    secureSettings:
      enabled: true
      entries:
        - secretName: "s3-credentials"
          key: "access_key"
          path: "s3.client.default.access_key"
        - secretName: "s3-credentials"
          key: "secret_key"
          path: "s3.client.default.secret_key"
```

### 4. Configure Ingress (Optional)

Create an ingress resource for external access:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: elasticsearch-ingress
  namespace: elasticsearch
spec:
  rules:
    - host: elasticsearch.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: shared-elastic-es-http
                port:
                  number: 9200
```

## Troubleshooting

### Pods Not Starting

**Symptom**: Pods stuck in `Pending` or `ContainerCreating` state

**Solutions**:

1. Check resource availability:
   ```bash
   kubectl describe pod <pod-name> -n elasticsearch
   ```

2. Check storage provisioning:
   ```bash
   kubectl get pvc -n elasticsearch
   kubectl describe pvc <pvc-name> -n elasticsearch
   ```

3. Ensure nodes meet system requirements:
   ```bash
   # vm.max_map_count should be at least 262144
   kubectl exec <pod-name> -n elasticsearch -- sysctl vm.max_map_count
   ```

### Cluster Health Yellow or Red

**Symptom**: Cluster health is not green

**Solutions**:

1. Check cluster status:
   ```bash
   kubectl describe elasticsearch shared-elastic -n elasticsearch
   ```

2. View pod logs:
   ```bash
   kubectl logs <pod-name> -n elasticsearch
   ```

3. Check for unassigned shards:
   ```bash
   curl -k -u "elastic:$PASSWORD" \
     https://localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason
   ```

### Out of Memory Errors

**Symptom**: Pods being OOMKilled

**Solutions**:

1. Increase memory limits in values:
   ```yaml
   resources:
     limits:
       memory: "8Gi"
     requests:
       memory: "8Gi"
   ```

2. Adjust Java heap size:
   ```yaml
   env:
     - name: ES_JAVA_OPTS
       value: "-Xms4g -Xmx4g"
   ```

3. Ensure heap size is ~50% of container memory

### Certificate Issues

**Symptom**: TLS/SSL connection errors

**Solutions**:

1. Verify certificates are generated:
   ```bash
   kubectl get secret -n elasticsearch | grep cert
   ```

2. Check certificate validity:
   ```bash
   kubectl describe secret shared-elastic-es-http-certs-public -n elasticsearch
   ```

### Performance Issues

**Symptom**: Slow queries or indexing

**Solutions**:

1. Check resource usage:
   ```bash
   kubectl top pods -n elasticsearch
   ```

2. Review cluster stats:
   ```bash
   curl -k -u "elastic:$PASSWORD" \
     https://localhost:9200/_cluster/stats?human&pretty
   ```

3. Scale data nodes:
   ```bash
   helm upgrade shared-elastic ./chart \
     --namespace elasticsearch \
     --reuse-values \
     --set appspace.elastic.nodeSets[1].count=5
   ```

## Upgrade Procedure

### Minor Version Upgrade

```bash
# Update values file with new version
helm upgrade shared-elastic ./chart \
  --namespace elasticsearch \
  --reuse-values \
  --set appspace.elastic.version=8.15.2
```

### Configuration Changes

```bash
# Apply configuration changes
helm upgrade shared-elastic ./chart \
  --namespace elasticsearch \
  -f new-values.yaml
```

### Rollback

If upgrade fails:

```bash
# Rollback to previous version
helm rollback shared-elastic --namespace elasticsearch

# Or rollback to specific revision
helm rollback shared-elastic 2 --namespace elasticsearch
```

## Uninstallation

### Remove Helm Release

```bash
helm uninstall shared-elastic --namespace elasticsearch
```

### Clean Up Resources

```bash
# Delete PVCs (data will be lost!)
kubectl delete pvc -l elasticsearch.k8s.elastic.co/cluster-name=shared-elastic \
  -n elasticsearch

# Delete namespace
kubectl delete namespace elasticsearch
```

⚠️ **Warning**: Deleting PVCs will permanently delete all data!

## Next Steps

- [Chart README](chart/README.md) - Detailed configuration reference
- [ECK Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html) - ECK operator documentation
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html) - Elasticsearch reference

## Support

For issues or questions:
- Open an issue in the repository
- Check ECK operator logs: `kubectl logs -n elastic-system elastic-operator-0`
