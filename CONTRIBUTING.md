# Contributing to Shared Elastic Helm Chart

Thank you for your interest in contributing to the Shared Elastic Helm chart! This document provides guidelines and instructions for contributing.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Setup](#development-setup)
3. [Making Changes](#making-changes)
4. [Testing](#testing)
5. [Submitting Changes](#submitting-changes)
6. [Code Standards](#code-standards)

## Getting Started

### Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- Helm 3.0+
- kubectl
- Git
- ECK operator (for testing)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/shared-elastic.git
   cd shared-elastic
   ```

3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/appspace-cloud/shared-elastic.git
   ```

## Development Setup

### Install Development Tools

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kubectl
# See: https://kubernetes.io/docs/tasks/tools/

# Install kubeval (optional, for validation)
brew install kubeval  # macOS
# or download from: https://github.com/instrumenta/kubeval/releases
```

### Set Up Test Cluster

#### Using minikube

```bash
minikube start --cpus=4 --memory=8192
kubectl create -f https://download.elastic.co/downloads/eck/2.11.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.0/operator.yaml
```

#### Using kind

```bash
kind create cluster --config kind-config.yaml
kubectl create -f https://download.elastic.co/downloads/eck/2.11.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.0/operator.yaml
```

## Making Changes

### Branch Naming Convention

Use descriptive branch names:
- `feature/add-new-nodepool`
- `fix/correct-storage-class`
- `docs/update-readme`

Create a branch:
```bash
git checkout -b feature/your-feature-name
```

### Chart Structure

```
chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── README.md              # Chart documentation
├── templates/
│   ├── _helpers.tpl       # Template helpers
│   ├── elasticsearch.yaml  # Main resource
│   └── NOTES.txt          # Post-install notes
└── examples/              # Example configurations
    ├── values-dev.yaml
    ├── values-minimal.yaml
    └── values-production.yaml
```

### Common Changes

#### Adding a New Configuration Option

1. Add the option to `values.yaml` with a sensible default
2. Document the option in comments
3. Update `_helpers.tpl` if needed
4. Update `elasticsearch.yaml` template to use the option
5. Update `chart/README.md` documentation
6. Add tests for the new option

Example:

```yaml
# In values.yaml
appspace:
  elastic:
    # Enable remote cluster connections
    remoteCluster:
      enabled: false
      # seeds: []
```

```yaml
# In _helpers.tpl
{{- define "elastic.remoteCluster" -}}
{{- if .Values.appspace.elastic.remoteCluster.enabled }}
remoteCluster:
  {{- toYaml .Values.appspace.elastic.remoteCluster | nindent 2 }}
{{- end }}
{{- end }}
```

#### Updating Elasticsearch Version

1. Update `appVersion` in `Chart.yaml`
2. Update default version in `values.yaml`
3. Test with the new version
4. Update documentation

#### Adding Example Configuration

1. Create new file in `examples/` directory
2. Follow naming convention: `values-{environment}.yaml`
3. Add complete, working configuration
4. Document in chart README

## Testing

### Linting

Always lint your changes:

```bash
# Lint the chart
helm lint chart/

# Check for syntax errors
helm template test chart/ > /dev/null
```

### Template Testing

Test template rendering with different values:

```bash
# Test default values
helm template test chart/

# Test with minimal config
helm template test chart/ -f chart/examples/values-minimal.yaml

# Test with production config
helm template test chart/ -f chart/examples/values-production.yaml

# Test specific overrides
helm template test chart/ \
  --set appspace.elastic.nodeSets[0].count=5 \
  --set appspace.elastic.version=8.16.0
```

### Validation

Validate generated manifests:

```bash
# Using kubectl
helm template test chart/ | kubectl apply --dry-run=client -f -

# Using kubeval (if installed)
helm template test chart/ | kubeval
```

### Integration Testing

Test on a real cluster:

```bash
# Create test namespace
kubectl create namespace test-elastic

# Install chart
helm install test chart/ --namespace test-elastic

# Wait for deployment
kubectl wait --for=condition=Ready elasticsearch/shared-elastic \
  --namespace test-elastic --timeout=600s

# Verify
kubectl get elasticsearch -n test-elastic
kubectl get pods -n test-elastic

# Clean up
helm uninstall test --namespace test-elastic
kubectl delete pvc --all -n test-elastic
kubectl delete namespace test-elastic
```

### Test Checklist

Before submitting, verify:

- [ ] `helm lint chart/` passes without errors
- [ ] All example values files render correctly
- [ ] Templates generate valid Kubernetes manifests
- [ ] Chart installs successfully on a test cluster
- [ ] Elasticsearch cluster reaches green health
- [ ] Documentation is updated
- [ ] NOTES.txt displays correctly

## Submitting Changes

### Commit Guidelines

Write clear commit messages:

```
type: brief description (max 50 chars)

Detailed explanation of changes (if needed).
Include motivation and what changed.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/tooling changes

Examples:
```
feat: add support for custom TLS certificates

docs: update installation instructions for ECK 2.11

fix: correct storage class name in production values
```

### Creating a Pull Request

1. Ensure all tests pass
2. Update documentation
3. Commit your changes:
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

4. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

5. Create a Pull Request on GitHub
   - Use a descriptive title
   - Reference related issues
   - Describe what changed and why
   - Include test results

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Breaking change

## Testing
- [ ] Linted with helm lint
- [ ] Tested template rendering
- [ ] Tested on Kubernetes cluster
- [ ] Updated documentation

## Checklist
- [ ] Chart version bumped (if needed)
- [ ] Documentation updated
- [ ] Examples updated (if needed)
- [ ] Tests pass
```

## Code Standards

### YAML Formatting

- Use 2 spaces for indentation
- Use lowercase for keys
- Use camelCase for value keys in values.yaml
- Add comments for complex configurations

### Template Best Practices

1. **Use helper templates** for repeated logic
2. **Validate required values** with `required` function
3. **Provide sensible defaults** for all values
4. **Use conditional logic** sparingly
5. **Comment complex templates**

Example:
```yaml
{{- if .Values.appspace.elastic.monitoring.enabled }}
monitoring:
  {{- if .Values.appspace.elastic.monitoring.metrics }}
  metrics:
    {{- required "metrics.elasticsearchRefs required when monitoring enabled" .Values.appspace.elastic.monitoring.metrics | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
```

### Documentation Standards

- Write in clear, simple English
- Use code blocks for commands
- Include examples for complex configurations
- Keep README up to date
- Document breaking changes

### Values File Standards

```yaml
# Group related settings
appspace:
  elastic:
    # Use descriptive comments
    name: "shared-elastic"  # Elasticsearch cluster name
    
    # Provide defaults for optional settings
    monitoring:
      enabled: false
      # metrics:
      #   elasticsearchRefs:
      #     - name: monitoring-cluster
```

## Review Process

1. **Automated Checks**: Linting and validation run automatically
2. **Code Review**: Maintainers review for:
   - Code quality
   - Test coverage
   - Documentation
   - Breaking changes
3. **Testing**: Changes tested on real cluster
4. **Merge**: Once approved, changes are merged

## Getting Help

- **Issues**: Open an issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check existing docs first

## Release Process

Maintainers follow semantic versioning:

- **Major**: Breaking changes (v1.0.0 → v2.0.0)
- **Minor**: New features (v1.0.0 → v1.1.0)
- **Patch**: Bug fixes (v1.0.0 → v1.0.1)

Chart version is updated in `Chart.yaml`:
```yaml
version: 1.1.0  # Chart version
appVersion: "8.15.1"  # Elasticsearch version
```

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Questions?

Feel free to open an issue or reach out to maintainers!

Thank you for contributing! 🎉
