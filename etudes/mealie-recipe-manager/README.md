# Project

Highly available installation of [Mealie recipe manager](https://nightly.mealie.io).

## Design details

- Frontend (web service and API) deployed as containers on cloud provider container platform
- Use cloud provider native database instance
- Shared storage attached to all containers to share static user uploaded data (recipe images, etc)
- Loadbalancer and autoscaling to ensure scale out/in based on system load

## Implementation details

- Deploy [Mealie recipe manager](https://nightly.mealie.io) on ECS (Fargate)
- Use RDS (Postgres) as DB
- Set up ELB for autoscaling

# Usage

## Deploy everything

In `terraform/`:

```
$ terraform init
$ terraform apply
```


# Tips

## Exec in to running ECS task

Install AWS CLI [SSM plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

```
aws ecs list-tasks --cluster mealie-recipe-manager
aws ecs execute-command --cluster mealie-recipe-manager --task 05420fe1e3c04d648aaa37a28736b42b --container mealie-frontend --interactive --command "/bin/sh"
```
