FROM rocker/rstudio:4.4.0

# Description: RStudio version 4.4.0  with JupyterLab and Quarto - add openssh client and server, pandoc, and cairosvg
LABEL description="RStudio version 4.4.0 with JupyterLab and Quarto"

ARG DEFAULT_USER
ARG MAMBA_VERSION="24.3.0-0"

COPY scripts/default_user.sh /rocker_scripts/default_user.sh
COPY scripts/conda_soft_links.sh /tmp/conda_soft_links.sh

# Extra packages for R
RUN sudo apt-get update && \
    sudo apt-get -y install less curl gzip lsof libz-dev libbz2-dev liblzma-dev libxml2 libxml2-dev libxt6 libglpk-dev libmysqlclient21 libnss-sss openssh-client openssh-server cargo && \
    sudo apt-get clean

RUN Rscript -e 'install.packages(c("tidyverse","ggplot2","reshape2","cowplot","dplyr","tidyr","vcfR"))'
RUN Rscript -e 'install.packages("BiocManager"); BiocManager::install(version = "3.19",ask = FALSE)'
RUN Rscript -e 'BiocManager::install(c("bsseq","DESeq2","rtracklayer"))'

# Install conda (mamba version) with Jupyter
ENV CONDA_DIR /opt/conda
RUN curl -L -O "https://github.com/conda-forge/miniforge/releases/download/${MAMBA_VERSION}/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash Miniforge3-$(uname)-$(uname -m).sh -f -b -p /opt/conda && \
    rm -f Miniforge3-$(uname)-$(uname -m).sh && \
    $CONDA_DIR/bin/mamba install -y -c conda-forge jupyterlab nb_conda_kernels && \
    $CONDA_DIR/bin/pip install jupyter_contrib_nbextensions && \
    $CONDA_DIR/bin/mamba install -y -c conda-forge jupyterlab-spellchecker Jinja2 jupyter-ai && \
    $CONDA_DIR/bin/pip3 install --root-user-action=ignore jupyterlab-quarto jupyter-ai[all] jupyterlab_favorites jupyterlab-git


# Create "basic-tools" and "tensorflow" conda environment and install some basic tools
COPY env/*.yml /tmp/
RUN $CONDA_DIR/bin/mamba env create -f /tmp/basic-tools.yml && \
    $CONDA_DIR/bin/conda clean -y --all

# soft link conda bin
RUN bash /tmp/conda_soft_links.sh $CONDA_DIR/bin

# Custom for RIS
RUN bash /rocker_scripts/default_user.sh "${DEFAULT_USER}" && \
    echo "server-user=${DEFAULT_USER}" >> /etc/rstudio/rserver.conf

EXPOSE 8787

RUN conda activate basic-tools

CMD ["/init"]

# bsub build command
# bsub -G compute-dspencer -q general-interactive -Is -a 'docker_build(dhspence/docker-rocker:jupyter240701)' -- --tag dhspence/docker-rocker:jupyter240701 --build-arg DEFAULT_USER=${USER} -f /storage1/fs1/dspencer/Active/spencerlab/dhs/git/docker-rocker/Dockerfile /storage1/fs1/dspencer/Active/spencerlab/dhs/git/docker-rocker/

# bsub run command
# $LSF_DOCKER_VOLUMES $HOME/rstudio_db/:/var/lib/rstudio-server\" LSF_DOCKER_PORTS=\"$port:$port\" bsub -eo $eo -oo $oo -g $group -G compute-dspencer -q $queue -R \"select[mem>=$mem1 && port$port=1] span[hosts=1] $mem2\" -n $cores -J \"quarto-jupyter\" -a \"docker($mycont)\" jupyter lab --allow-root --no-browser --ip='*' --NotebookApp.token='' --NotebookApp.password=''"