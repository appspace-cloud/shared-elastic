# Shared Elastic

Infrastructure code to deploy and manage a shared Elasticsearch cluster used across multiple services and environments.

## Overview

This repository contains a comprehensive Helm chart for deploying Elasticsearch using the Elastic Cloud on Kubernetes (ECK) operator. The chart provides production-ready configurations with multiple node types, high availability, and security features.

## Quick Start

### Prerequisites

- Kubernetes cluster (1.21+)
- Helm (3.0+)
- ECK Operator installed

### Install ECK Operator

```bash
kubectl create -f https://download.elastic.co/downloads/eck/2.11.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.0/operator.yaml
```

### Install Elasticsearch

```bash
# Basic installation
helm install shared-elastic ./chart --namespace elasticsearch --create-namespace

# With custom values
helm install shared-elastic ./chart \
  -f chart/examples/values-production.yaml \
  --namespace elasticsearch \
  --create-namespace
```

### Access Elasticsearch

```bash
# Get the elastic user password
kubectl get secret shared-elastic-es-elastic-user \
  -n elasticsearch \
  -o go-template='{{.data.elastic | base64decode}}'

# Port forward to access locally
kubectl port-forward -n elasticsearch service/shared-elastic-es-http 9200:9200

# Access Elasticsearch
curl -k -u "elastic:<password>" https://localhost:9200
```

## Features

- **Multiple Node Types**: Dedicated master, data, and coordinating nodes
- **High Availability**: Pod disruption budgets and multiple replicas
- **Security**: TLS/SSL encryption for HTTP and transport layers
- **Resource Management**: Configurable CPU and memory limits
- **Persistent Storage**: Volume claims for data persistence
- **Monitoring**: Integration with ECK Stack Monitoring
- **Flexible Configuration**: Multiple example configurations (minimal, dev, production)

## Documentation

For detailed documentation, see the [chart README](chart/README.md).

## Example Configurations

The repository includes several example configurations:

- **Minimal**: Single-node setup for testing (`chart/examples/values-minimal.yaml`)
- **Development**: Single all-in-one node with moderate resources (`chart/examples/values-dev.yaml`)
- **Production**: Multi-node cluster with dedicated roles (`chart/examples/values-production.yaml`)

## Configuration

Key configuration options:

```yaml
appspace:
  elastic:
    name: "shared-elastic"          # Cluster name
    version: "8.15.1"                # Elasticsearch version
    nodeSets:                        # Node configuration
      - name: master
        count: 3
        config:
          node.roles: ["master"]
    podDisruptionBudget:            # High availability
      enabled: true
      spec:
        minAvailable: 2
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

See repository license for details.
