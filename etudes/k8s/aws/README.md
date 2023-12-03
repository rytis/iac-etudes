# Pre-install

```
brew install kubectl
```

# Install

```
$ terraform init
$ terraform apply
```

# Configure `kubectl`

```
$ aws eks --region us-east-2 update-kubeconfig --name test-eks
```
