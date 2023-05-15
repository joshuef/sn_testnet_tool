FROM arm64v8/python:3.11.3-bullseye 

RUN apt-get update -y && \
    apt-get install -y bsdmainutils curl jq less unzip && \
    adduser --disabled-password --gecos '' runner && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install --update && \
    rm -rf aws awscliv2.zip && \
    TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version) && \
    curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
      -o terraform.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform.zip && \
    echo "export PATH=\$PATH:/home/runner/.local/bin" >> /home/runner/.bashrc

USER runner
WORKDIR /home/runner
# Set the environment variable to reload the bash source
# ENV BASH_ENV=/home/runner/.bashrc
RUN pip install --user ansible boto3 
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh  -s -- --default-toolchain stable -y
# RUN chmod +x rustup-init 
# RUN ./rustup-init --default-toolchain stable --no-modify-path -y
RUN . ${HOME}/.cargo/env && cargo install just 
#-Z sparse-registry
RUN echo "source $HOME/.cargo/env" >> /home/runner/.bashrc

CMD ["/bin/bash", "-l"]
