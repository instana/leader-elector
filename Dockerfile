FROM --platform=linux/amd64 registry.access.redhat.com/ubi8/ubi-minimal:latest AS elector-builder

ENV PATH="$PATH:/usr/local/go/bin" \
    GOPATH=/go \
    GO_VERSION=1.16.6
# Needs separate ENV entry to be able to use the version defined before
ENV GO_SHA256="be333ef18b3016e9d7cb7b1ff1fdb0cac800ca0be4cf2290fe613b3d069dfe0d go${GO_VERSION}.linux-amd64.tar.gz"

RUN microdnf install git tar gzip \
    && curl -L --fail --show-error --silent "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o "go${GO_VERSION}.linux-amd64.tar.gz" \
    && echo "${GO_SHA256}" | sha256sum --check \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && mkdir -p "${GOPATH}" \
    && go version

ADD election /go/src/k8s.io/contrib/election

RUN cd /go/src/k8s.io/contrib/election \
    && CGO_ENABLED=0 GOOS=linux GOARCH=s390x GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o leader-elector_s390x example/main.go \
    && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o leader-elector_amd64 example/main.go \
    && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o leader-elector_arm64 example/main.go \
    && mkdir -p /usr/bin/linux/{amd64,arm64,s390x} \
    && chmod u+x leader-elector_* && \
    cp leader-elector_amd64 /usr/bin/linux/amd64/leader-elector && \
    cp leader-elector_arm64 /usr/bin/linux/arm64/leader-elector && \
    cp leader-elector_s390x /usr/bin/linux/s390x/leader-elector


FROM --platform=linux/amd64 registry.access.redhat.com/ubi8/ubi-minimal:latest AS hostname-builder

RUN microdnf install golang git \
    && mkdir -p /go

ENV GOPATH=/go

WORKDIR /go/src/hostname

COPY hostname.go .

RUN cd /go/src/hostname \
    && CGO_ENABLED=0 GOOS=linux GOARCH=s390x GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o hostname_s390x hostname.go \
    && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o hostname_amd64 hostname.go \
    && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o hostname_arm64 hostname.go \
    && mkdir -p /usr/bin/linux/{amd64,arm64,s390x} \
    && chmod u+x hostname_* && \
    cp hostname_amd64 /usr/bin/linux/amd64/hostname && \
    cp hostname_arm64 /usr/bin/linux/arm64/hostname && \
    cp hostname_s390x /usr/bin/linux/s390x/hostname


# Debug image includes busybox which provides a shell otherwise the containers the same.
# Shell is needed so that shell-expansion can be used in parameters such as --id=$(/app/hostname)
FROM gcr.io/distroless/base:debug

ARG TARGETPLATFORM='linux/amd64'

MAINTAINER Instana Engineering <support@instana.com>

# Docker defaults to /bin/sh need to override to use busybox shell.
SHELL ["/busybox/sh", "-c"]

COPY --from=hostname-builder /usr/bin/${TARGETPLATFORM}/hostname /app/hostname
COPY --from=elector-builder /usr/bin/${TARGETPLATFORM}/leader-elector /app/server

USER 1001
ENTRYPOINT /app/server --id=$(/app/hostname) $@
