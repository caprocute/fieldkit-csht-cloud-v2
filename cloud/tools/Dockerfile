FROM rust:latest AS rust-tools
WORKDIR /work
RUN git clone https://github.com/conservify/dev-ops.git
RUN cd dev-ops && make rust-binaries
RUN pwd

FROM golang:latest AS golang-tools
WORKDIR /work
COPY . .
RUN cd passwords && go build -o passwords passwords.go

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl postgresql-client ruby jq openssh-client net-tools bzip2 xz-utils
WORKDIR /work
COPY --from=rust-tools /work/dev-ops/build/desecreter .
COPY --from=rust-tools /work/dev-ops/build/deployer .
COPY --from=golang-tools /work/passwords/passwords .
