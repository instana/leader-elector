# Leader-elector sidecar container

This repo contains the election directory forked from kubernetes/contrib, later forked by openshift/leader-elector.
The original version has not been updated since July 2016 and has security issues.

It was forked to change certain behaviour in the code, update some dependencies and include multi-platform builds equal
to the platforms that the Instana Agent [supports](https://www.instana.com/docs/setup_and_manage/host_agent/on).

Info on how to use this can be found [on Kubernetes blog](https://kubernetes.io/blog/2016/01/simple-leader-election-with-kubernetes/).


## Building

```shell
REPOSITORY=instana/leader-elector make
```

## Publishing

```shell
REPOSITORY=instana/leader-elector make publish
```

## Multi-arch Builds

Docker for Mac has all support for multi-arch builds included. For Linux hosts, some additional setup might be needed
to ensure multi-arch builds are working. Specifically look here: https://medium.com/@artur.klauser/building-multi-architecture-docker-images-with-buildx-27d80f7e2408

