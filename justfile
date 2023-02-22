deploy:
    coder template push -d nomad -y

build-base:
    cd images && docker build . -f base.Dockerfile -t ghcr.io/simse/coder-nomad/base:latest

build-node:
    cd images && docker build . -f node.Dockerfile -t ghcr.io/simse/coder-nomad/node:latest

run-node:
    docker run -it --entrypoint /bin/bash ghcr.io/simse/coder-nomad/node:latest