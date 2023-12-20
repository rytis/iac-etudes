# Get caller identity

When troubleshooting resource access problems it's useful to know
what identity is used when making a request. For example monting
EFS volume from an EC2 instance and using IAM authentication.

```
aws sts get-caller-identity
```
