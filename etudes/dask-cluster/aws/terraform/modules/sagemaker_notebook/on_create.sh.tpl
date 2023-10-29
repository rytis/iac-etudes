#!/bin/bash

set -e

sudo -u ec2-user -i <<'EOD'

# ----------------------------------------------------------------------------

unset SUDO_UID

MINICONDA_ROOT="/home/ec2-user/SageMaker/custom-miniconda"
MINICONDA_INSTALLER="Miniconda3-py310_23.9.0-0-Linux-x86_64.sh"
KERNEL_NAME="dask"

mkdir -p ${MINICONDA_ROOT}

curl -L "https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}" -o "${MINICONDA_ROOT}/miniconda3.sh"

bash "${MINICONDA_ROOT}/miniconda3.sh" -b -u -p "${MINICONDA_ROOT}/miniconda3"
rm -rf "${MINICONDA_ROOT}/miniconda3.sh"

source "${MINICONDA_ROOT}/miniconda3/bin/activate"

conda create --yes --name "${KERNEL_NAME}"
conda activate "${KERNEL_NAME}"

conda install --yes conda-libmamba-solver
conda config --set solver libmamba

conda install --yes ipykernel dask aiohttp requests

# ----------------------------------------------------------------------------

EOD

# ## as ec2-user:
# source "${MINICONDA_ROOT}/miniconda3/bin/activate"
# conda activate dask
# python -m ipykernel install --user --name dask --display-name dask
# ##
# systemctl restart jupyter-server
