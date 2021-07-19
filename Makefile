
SHELL := /bin/bash

ELECTOR_REPOSITORY ?= instana/leader-elector
ELECTOR_VERSION ?= test

.DEFAULT=all

.PHONY: all
all: build

.PHONY: build
build:
	docker buildx build --no-cache --platform linux/s390x --build-arg "TARGETPLATFORM=linux/s390x" -t $(ELECTOR_REPOSITORY):s390x-$(ELECTOR_VERSION) .
	docker buildx build --no-cache --platform linux/amd64 --build-arg "TARGETPLATFORM=linux/amd64" -t $(ELECTOR_REPOSITORY):amd64-$(ELECTOR_VERSION) .
	docker buildx build --no-cache --platform linux/arm64 --build-arg "TARGETPLATFORM=linux/arm64" -t $(ELECTOR_REPOSITORY):arm64-$(ELECTOR_VERSION) .

.PHONY: publish
publish:
	export DOCKER_CLI_EXPERIMENTAL=enabled
	docker push $(ELECTOR_REPOSITORY):s390x-$(ELECTOR_VERSION)
	docker push $(ELECTOR_REPOSITORY):amd64-$(ELECTOR_VERSION)
	docker push $(ELECTOR_REPOSITORY):arm64-$(ELECTOR_VERSION)
	docker manifest rm $(ELECTOR_REPOSITORY):$(ELECTOR_VERSION) || true
	docker manifest create $(ELECTOR_REPOSITORY):$(ELECTOR_VERSION) $(ELECTOR_REPOSITORY):s390x-$(ELECTOR_VERSION) $(ELECTOR_REPOSITORY):amd64-$(ELECTOR_VERSION) $(ELECTOR_REPOSITORY):arm64-$(ELECTOR_VERSION)
	docker manifest push --purge $(ELECTOR_REPOSITORY):$(ELECTOR_VERSION)

