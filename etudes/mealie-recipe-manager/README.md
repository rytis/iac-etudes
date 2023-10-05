- Deploy [Mealie recipe manager](https://nightly.mealie.io) on ECS (Fargate)
- Use RDS (Postgres) as DB
- Set up ELB for autoscaling

# Usage

# Notes

- To exec in to running ECS task
  - `aws ecs list-tasks --cluster mealie-recipe-manager`
  - `aws ecs execute-command --cluster mealie-recipe-manager --task 05420fe1e3c04d648aaa37a28736b42b --container mealie-frontend --interactive --command "/bin/sh"`
