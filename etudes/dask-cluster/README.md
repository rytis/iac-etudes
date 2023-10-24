- Set up [Dask](https://docs.dask.org/) cluster on ECS (Fargate)
- Use autoscaling to scale out
- Access
  - Sagemaker
  - Manager Airflow

# Usage

## Deploy everything

In `terraform/`:

```
$ terraform init
$ terraform apply
```

# Tips

## Port forward to container

```
aws ssm start-session \
  --target ecs:dask-cluster_1673cf6278af495282842b8ac1cc3ee8_1673cf6278af495282842b8ac1cc3ee8-2727946824
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8787"], "localPortNumber":["8787"]}'
```

Where `target`:

```
ecs:<ECS-cluster-name>_<task-id>_<container-runtime-id>
```
