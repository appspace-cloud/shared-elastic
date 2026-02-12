# Shared Elastic Helm Chart

A comprehensive Helm chart for deploying Elasticsearch using the Elastic Cloud on Kubernetes (ECK) operator. This chart provides a production-ready configuration with multiple node types, high availability, and security features.

## Overview

This Helm chart deploys an Elasticsearch cluster using the ECK operator's Elasticsearch custom resource. It supports:

- Multiple node types (master, data, coordinating)
- High availability with pod disruption budgets
- TLS/SSL encryption for HTTP and transport layers
- Resource management and limits
- Persistent storage with volume claims
- Monitoring and metrics integration
- Flexible configuration through values

## Prerequisites

Before installing this chart, ensure you have:

1. **Kubernetes cluster** (version 1.21+)
2. **Helm** (version 3.0+)
3. **ECK Operator** installed in your cluster

### Installing ECK Operator

```bash
# Add the Elastic Helm repository
helm repo add elastic https://helm.elastic.co
helm repo update

# Install ECK operator
kubectl create -f https://download.elastic.co/downloads/eck/2.11.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.0/operator.yaml

# Verify installation
kubectl get pods -n elastic-system
```

## Installation

### Basic Installation

```bash
# Install with default values
helm install shared-elastic ./chart

# Install in a specific namespace
helm install shared-elastic ./chart --namespace elasticsearch --create-namespace
```

### Custom Installation

```bash
# Install with custom values
helm install shared-elastic ./chart \
  --set appspace.elastic.name=my-cluster \
  --set appspace.elastic.version=8.15.1 \
  --namespace elasticsearch

# Install with a custom values file
helm install shared-elastic ./chart -f my-values.yaml
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `appspace.elastic.name` | Name of the Elasticsearch cluster | `shared-elastic` |
| `appspace.elastic.version` | Elasticsearch version | `8.15.1` |
| `appspace.elastic.podDisruptionBudget.enabled` | Enable Pod Disruption Budget | `true` |
| `appspace.elastic.podDisruptionBudget.spec.minAvailable` | Minimum available pods | `2` |

### Node Sets Configuration

The chart supports three types of node sets:

#### Master Nodes
Responsible for cluster coordination, index management, and cluster state.

```yaml
appspace:
  elastic:
    nodeSets:
      - name: master
        count: 3
        config:
          node.roles: ["master"]
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
```

#### Data Nodes
Responsible for storing and searching data.

```yaml
appspace:
  elastic:
    nodeSets:
      - name: data
        count: 3
        config:
          node.roles: ["data", "ingest"]
        resources:
          requests:
            memory: "4Gi"
            cpu: "2000m"
```

#### Coordinating Nodes
Responsible for routing requests and aggregating results.

```yaml
appspace:
  elastic:
    nodeSets:
      - name: coordinating
        count: 2
        config:
          node.roles: []
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
```

### Storage Configuration

Each node set can have its own persistent volume configuration:

```yaml
volumeClaimTemplates:
  - metadata:
      name: elasticsearch-data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 100Gi
      storageClassName: standard
```

### Security Configuration

#### TLS/SSL

TLS is enabled by default for both HTTP and transport layers:

```yaml
appspace:
  elastic:
    http:
      tls:
        enabled: true
        # Optional: Use custom certificate
        certificate:
          secretName: "elasticsearch-http-certs"
    
    transport:
      tls:
        enabled: true
```

#### Secure Settings

Store sensitive configuration in Kubernetes secrets:

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

### HTTP Service Configuration

Configure the Elasticsearch HTTP service:

```yaml
appspace:
  elastic:
    http:
      service:
        metadata:
          labels:
            service-type: elasticsearch
        spec:
          type: LoadBalancer
          externalTrafficPolicy: Local
```

### Monitoring

Enable monitoring with the ECK Stack Monitoring:

```yaml
appspace:
  elastic:
    monitoring:
      enabled: true
      metrics:
        elasticsearchRefs:
          - name: monitoring-cluster
            namespace: monitoring
      logs:
        elasticsearchRefs:
          - name: monitoring-cluster
            namespace: monitoring
```

## Usage

### Accessing Elasticsearch

#### Get Credentials

```bash
# Get the elastic user password
kubectl get secret shared-elastic-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}' \
  -n <namespace>
```

#### Port Forwarding

```bash
# Forward Elasticsearch port to local machine
kubectl port-forward service/shared-elastic-es-http 9200:9200 -n <namespace>

# Access Elasticsearch
curl -k -u "elastic:<password>" https://localhost:9200
```

#### From Within Cluster

```bash
# Service URL
https://shared-elastic-es-http.<namespace>.svc.cluster.local:9200
```

### Cluster Operations

#### Check Cluster Health

```bash
kubectl get elasticsearch -n <namespace>
```

#### View Cluster Status

```bash
kubectl describe elasticsearch shared-elastic -n <namespace>
```

#### Scale Node Sets

```bash
# Scale data nodes
helm upgrade shared-elastic ./chart \
  --set appspace.elastic.nodeSets[1].count=5 \
  --namespace <namespace>
```

#### Update Elasticsearch Version

```bash
helm upgrade shared-elastic ./chart \
  --set appspace.elastic.version=8.16.0 \
  --namespace <namespace>
```

## Examples

### Minimal Configuration

```yaml
appspace:
  elastic:
    name: "my-cluster"
    version: "8.15.1"
    nodeSets:
      - name: default
        count: 3
        config:
          node.roles: ["master", "data", "ingest"]
```

### Production Configuration

```yaml
appspace:
  elastic:
    name: "production-cluster"
    version: "8.15.1"
    
    podDisruptionBudget:
      enabled: true
      spec:
        minAvailable: 2
    
    nodeSets:
      - name: master
        count: 3
        config:
          node.roles: ["master"]
        volumeClaimTemplates:
          - metadata:
              name: elasticsearch-data
            spec:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 10Gi
              storageClassName: fast-ssd
      
      - name: data
        count: 5
        config:
          node.roles: ["data", "ingest"]
        volumeClaimTemplates:
          - metadata:
              name: elasticsearch-data
            spec:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 500Gi
              storageClassName: standard
      
      - name: coordinating
        count: 3
        config:
          node.roles: []
    
    http:
      service:
        spec:
          type: LoadBalancer
    
    monitoring:
      enabled: true
```

### Development Configuration

```yaml
appspace:
  elastic:
    name: "dev-cluster"
    version: "8.15.1"
    
    podDisruptionBudget:
      enabled: false
    
    nodeSets:
      - name: all-in-one
        count: 1
        config:
          node.roles: ["master", "data", "ingest"]
        podTemplate:
          spec:
            containers:
              - name: elasticsearch
                resources:
                  requests:
                    memory: "2Gi"
                    cpu: "500m"
                  limits:
                    memory: "2Gi"
        volumeClaimTemplates:
          - metadata:
              name: elasticsearch-data
            spec:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 10Gi
```

## Upgrading

### Upgrade the Chart

```bash
# Upgrade with new values
helm upgrade shared-elastic ./chart \
  --namespace <namespace> \
  --reuse-values \
  --set appspace.elastic.version=8.16.0
```

### Rollback

```bash
# Rollback to previous release
helm rollback shared-elastic --namespace <namespace>
```

## Uninstallation

```bash
# Uninstall the release
helm uninstall shared-elastic --namespace <namespace>

# Note: This will not delete PVCs. To delete them:
kubectl delete pvc -l elasticsearch.k8s.elastic.co/cluster-name=shared-elastic -n <namespace>
```

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>
```

#### Cluster Health Issues

```bash
# Check cluster status
kubectl get elasticsearch shared-elastic -n <namespace>

# View detailed status
kubectl describe elasticsearch shared-elastic -n <namespace>
```

#### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n <namespace>

# Describe PVC
kubectl describe pvc <pvc-name> -n <namespace>
```

#### Memory Issues

If pods are being OOMKilled, increase memory limits:

```yaml
resources:
  limits:
    memory: "8Gi"
env:
  - name: ES_JAVA_OPTS
    value: "-Xms4g -Xmx4g"
```

## Best Practices

1. **Resource Allocation**: Always set appropriate resource requests and limits
2. **Storage**: Use SSD storage classes for production workloads
3. **High Availability**: Deploy at least 3 master nodes and 2 data nodes
4. **Monitoring**: Enable monitoring to track cluster health and performance
5. **Security**: Use TLS for all communications and rotate passwords regularly
6. **Backups**: Implement snapshot/restore policies for disaster recovery
7. **Updates**: Test Elasticsearch version updates in a non-production environment first
8. **Node Separation**: Use dedicated node sets for different roles in production

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          ECK Operator                                │  │
│  │  (Manages Elasticsearch Resources)                   │  │
│  └─────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐  │
│  │       Elasticsearch Cluster (shared-elastic)        │  │
│  │                                                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │  │
│  │  │Master Nodes  │  │  Data Nodes  │  │Coordinating│ │  │
│  │  │   (x3)       │  │   (x3)       │  │  Nodes    │ │  │
│  │  │              │  │              │  │   (x2)    │ │  │
│  │  │ - Cluster    │  │ - Store Data │  │ - Route   │ │  │
│  │  │   Management │  │ - Search     │  │   Requests│ │  │
│  │  │ - Index      │  │ - Ingest     │  │ - Aggregate│ │  │
│  │  │   Management │  │              │  │            │ │  │
│  │  └──────────────┘  └──────────────┘  └───────────┘ │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │         Persistent Volume Claims             │  │  │
│  │  │  (Separate storage for each node)            │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Services & Endpoints                               │  │
│  │  - HTTP Service (Port 9200)                         │  │
│  │  - Transport Service (Port 9300)                    │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Support

For issues, questions, or contributions:

- **Repository**: https://github.com/appspace-cloud/shared-elastic
- **ECK Documentation**: https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html
- **Elasticsearch Documentation**: https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html

## License

This chart is provided under the terms specified in the repository license.

## Maintainers

- AppSpace Cloud Team (team@appspace.cloud)
