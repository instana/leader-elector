FROM --platform=linux/amd64 registry.access.redhat.com/ubi8/ubi-minimal:latest AS go-builder

ENV PATH="$PATH:/usr/local/go/bin" \
    GOPATH=/go \
    GO_VERSION=1.18
# Needs separate ENV entry to be able to use the version defined before
ENV GO_SHA256="e85278e98f57cdb150fe8409e6e5df5343ecb13cebf03a5d5ff12bd55a80264f go${GO_VERSION}.linux-amd64.tar.gz"

RUN microdnf install git tar gzip \
    && curl -L --fail --show-error --silent "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o "go${GO_VERSION}.linux-amd64.tar.gz" \
    && echo "${GO_SHA256}" | sha256sum --check \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && mkdir -p "${GOPATH}" \
    && go version


FROM --platform=linux/amd64 go-builder AS elector-builder

ARG TARGETPLATFORM='linux/amd64'

ADD election /go/src/k8s.io/contrib/election

RUN cd /go/src/k8s.io/contrib/election \
    && export ARCH=$(case "${TARGETPLATFORM}" in 'linux/amd64') echo 'amd64' ;; 'linux/arm64') echo 'arm64' ;; 'linux/s390x') echo 's390x' ;; 'linux/ppc64le') echo 'ppc64le' ;; esac) \
    && CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o leader-elector_${ARCH} example/main.go \
    && mkdir -p /usr/bin/linux/${ARCH} \
    && chmod u+x leader-elector_* && \
    cp leader-elector_${ARCH} /usr/bin/linux/${ARCH}/leader-elector


FROM --platform=linux/amd64 go-builder AS hostname-builder

ARG TARGETPLATFORM='linux/amd64'

WORKDIR /go/src/hostname

COPY hostname.go .

RUN cd /go/src/hostname \
    && export ARCH=$(case "${TARGETPLATFORM}" in 'linux/amd64') echo 'amd64' ;; 'linux/arm64') echo 'arm64' ;; 'linux/s390x') echo 's390x' ;; 'linux/ppc64le') echo 'ppc64le' ;; esac) \
    && CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} GO111MODULE=off go build -a -installsuffix cgo -ldflags '-w' -o hostname_${ARCH} hostname.go \
    && mkdir -p /usr/bin/linux/${ARCH} \
    && chmod u+x hostname_* && \
    cp hostname_${ARCH} /usr/bin/linux/${ARCH}/hostname


# Debug image includes busybox which provides a shell otherwise the containers the same.
# Shell is needed so that shell-expansion can be used in parameters such as --id=$(/app/hostname)
FROM gcr.io/distroless/base:debug

ARG TARGETPLATFORM='linux/amd64'

MAINTAINER Instana Engineering <support@instana.com>

# Docker defaults to /bin/sh need to override to use busybox shell.
SHELL ["/busybox/sh", "-c"]

COPY --from=hostname-builder /usr/bin/${TARGETPLATFORM}/hostname /app/hostname
COPY --from=elector-builder /usr/bin/${TARGETPLATFORM}/leader-elector /app/server

# Limit continuous logging of the lease on INFO level
ENV GLOG_vmodule="leaderelection=3"

USER 1001
ENTRYPOINT /app/server --id=$(/app/hostname) $@
