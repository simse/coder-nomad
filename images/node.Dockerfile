FROM ghcr.io/simse/coder-nomad/base:latest

USER root

# nvm environment variables
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 18

# install nvm
RUN mkdir /usr/local/nvm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH
ENV PATH $NVM_DIR:$PATH

USER coder