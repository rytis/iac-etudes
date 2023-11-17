# Project

Build a [Dask](https://docs.dask.org/) cluster. Create an instance of either
[Jupyter](https://jupyter.org) Notebook or JupyterLab that can access the cluster.
Create an S3 compatible storage to store data.

## Design details

- Single Dask scheduler instance
- Multiple Dask workers in autoscaling group to allow for higher loads
- Use cloud provider managed Jupyter (if available)
- Allow external connection to the cluster

## Implementation details

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

## Running jobs on the cluster

### From local workstation

To run jobs on the remote cluster you need to set up port forwarding to Dask scheduler task (see "Tips" section)
on port 8786 (scheduler port).

Once port forwarding is enabled, connect to the Dask cluster using workstation IP and Port:

```
import distributed
import dask.dataframe as dd


def main():
    client = distributed.Client("tcp://127.0.0.1:8786")
    print(client)
    df = dd.read_parquet('https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-07.parquet',
                         parse_dates=['tpep_pickup_datetime', 'tpep_dropoff_datetime'])
    print(len(df))


if __name__ == "__main__":
    main()
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
