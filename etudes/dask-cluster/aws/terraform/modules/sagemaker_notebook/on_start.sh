#!/bin/bash

set -e

sudo -u ec2-user -i <<'EOD'

MINICONDA_ROOT="/home/ec2-user/SageMaker/custom-miniconda"
KERNEL_NAME="dask"

source "${MINICONDA_ROOT}/miniconda3/bin/activate"
conda activate "${KERNEL_NAME}"
python -m ipykernel install --user --name "${KERNEL_NAME}" --display-name "${KERNEL_NAME}"

EOD

systemctl --no-block restart jupyter-server

