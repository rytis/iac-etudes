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

# Tips

## List all available EKS add-ons

```
$ aws eks describe-addon-versions --kubernetes-version 1.28 --query "addons[].addonName"
```

## Mount EFS volume on test EC2 instance

```
yum install -y amazon-efs-utils
mount -t efs -o tls,iam fs-xxx /mnt
```
