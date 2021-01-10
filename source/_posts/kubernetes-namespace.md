---
title: k8s 命名空间
date: 2021-01-10 18:08:30
tags:
    - Kubernetes
    - Namespace
category: 码梦为生
---

## 什么是命名空间

在单个 k8s 集群中可以创建多个命名空间（namespace），它们在逻辑上彼此隔离，相当于在一个集群中创建了多个虚拟集群。

命名空间用于分组管理 k8s 集群中的资源对象，每一个添加到 k8s 集群的工作负载（workload）都必须放在一个命名空间中。

单个命名空间中的同类资源的名称必须唯一，但是相同的名称可以在不同的命名空间中使用。另外你还可以通过定义 ResourceQuota 对象来限制指定命名空间下资源的使用，利用 RBAC 来控制命名空间下的访问权限。

## 为什么需要命名空间

使用单个命名空间对于小团队来说会很方便，但是对于大型团队或大型组织来说，拥有多个名称空间有很多好处，包括：

- `隔离`：使用命名空间可以把多个团队或多个项目隔离到不同的环境中，不同的团队可以在不同的命名空间中使用相同的资源名称，对一个命名空间执行的操作也不会影响到其他命名空间。

- `资源控制`：可以通过资源配额来限制单个命名空间可使用的 CPU 和内存资源，这样可以确保每个团队或项目都具有运行所需的资源，并且不会占用所有的可用资源。

- `权限控制`：可以通过 RBAC 来定义角色和权限，这样可以确保只有授权用户才能访问给定命名空间中的资源。 

- `性能`：使用命名空间可以提高集群的性能，划分多个命名空间后，每个命名空间下的资源相比使用单个命名空间就会少很多，那么 k8s api 操作的对象集合就会少很多，从而减少 k8s api 的延迟。

## 初始命名空间

k8s 初始会创建四个命名空间：

- `default`：默认命名空间，如果你创建的资源没有指定命名空间，就会放在这个命名空间下。一般在正式环境不建议把服务部署到这个命名空间，因为这个命名空间下的资源会很混乱而且很难清理。

- `kube-system`：k8s 系统组件使用的命名空间，例如 `apiserver`、`scheduler`、`controller-manager` 等组件就在这个命名空间。一般情况下，我们应该避免使用这个命名空间，任何对这个命名空间的部署都可能是危险的操作。

- `kube-public`：用来存放公共资源的命名空间，主要是由 k8s 自己管理。

- `kube-node-lease`：用来存放与节点相关的租期（Lease）对象，该对象用来提升大规模集群下节点心跳检测的性能。

虽然你可以把服务部署到这些初始创建的命名空间，但还是推荐单独创建你自己的命名空间来管理你的服务和资源，避免对这些初始命名空间的操作影响到整个集群。另外也不推荐将服务部署到 `default` 命名空间，因为你一不小心可能就把资源创建到了这个命名空间，导致这个命名空间下遗留了大量无用的资源，并且不好清理，在平时测试 k8s 功能或者 demo 的时候倒是可以使用 `default` 命名空间。

## 命名空间的操作

### 查看命名空间

显示集群中所有的命名空间：

```sh
$ kubectl get namespace
NAME              STATUS   AGE
default           Active   27d
kube-node-lease   Active   27d
kube-public       Active   27d
kube-system       Active   27d
```

> kubectl 命令中的 `namespace` 可以缩写成 `ns`，所以可以使用 `kubectl get ns` 少打几个字符，这里为了展示就不用缩写了。

命名空间包含 `Active` 和 `Terminating` 两种状态。`Active` 表示命名空间正在被使用中，`Terminating` 表示命名空间正在被删除。

查询指定命令空间下的 pod（`--namespace` 可以缩写成 `-n`）：

```sh
$ kubectl get pod --namespace default
NAME                            READY   STATUS    RESTARTS   AGE
nginx-7b9c8ddb75-pctld          1/1     Running   0          2d22h
```

### 创建命名空间

使用命令创建命名空间：

```sh
$ kubectl create namespace demo
```

也可以使用 yaml 来创建：

```yaml
# demo-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
```

```sh
$ kubectl apply -f demo-namespace.yaml
```

### 删除命名空间

删除一个命名空间：

```sh
$ kubectl delete namespace demo
```

要注意的是，删除一个命名空间后，会自动删除该命名空间的下的所有资源，所以一定要小心使用。在删除命名空间之前，最好先使用 `kubectl get all -n <namespace>` 列出命名空间下的相关资源，确定资源都是可删除的，再进行删除操作。

初始创建的 `default`、`kube-system`、`kube-public` 命名空间是不可删除的。

## 跨命名空间通信

k8s 命名空间虽然资源隔离，但是一个命名空间中的服务还是可以与另一个命名空间中的服务进行通信的。这是很常见的需求，例如 A 团队（A 命名空间）的服务要访问 B 团队（B 命名空间）的服务。

如果你创建了一个 k8s service，k8s 就会创建一个对应的 dns 条目：

```sh
<service-name>.<namespace-name>.svc.cluster.local
```

比如我在 `team-a` 命名空间下创建了名为 `user` 的 k8s service，那么对应 dns 名称就是：

```sh
user.team-a.svc.cluster.local
```

在同一个命名空间下，可以通过 k8s service 的名称直接访问到对应服务，比如在 `team-a` 命名空间下的其他服务要访问 `user` 服务，`user` 服务暴露的端口是 8080，那么通过 `user:8080` 就能找到 `user` 服务，dns 会自动解析为完整地址 `user.team-a.svc.cluster.local`。

但是，如果是不同命名空间下的服务要相互访问，则需使用 k8 service 名称加上命名空间名称。比如在 `team-b` 命名空间访问 `team-a` 命名空间的 `user` 服务，就要使用 `user.team-a:8080` 地址来访问。

## 命名空间划分策略

不同的团队和组织可以采用不同的命名空间策略，具体取决于团队规模，组织结构，以及项目的复杂性等因素。一般有下面几种划分策略：

- 根据团队或项目划分

  对于服务较少的小团队来说，使用单个命名空间就足够了。对于大型团队或大型项目来说，为每个单独的团队或项目创建一个命名空间，可以很好进行管理，并利用前面我们提到的命名空间的优点。

  例如：`team-a`、`team-b`

- 根据开发环境划分

  对于较小的团队或项目来说，命名空间很适合用来在集群中划分测试、预发布以及生成环境。但是通常情况下，建议用完全独立的集群区分不同的开发环境，以确保最大程度的隔离。

  例如：`dev`、`stage`、`prod`

- 根据服务层级划分

  后台服务可能分为多个层级，比如有聚合服务、业务逻辑服务、通用组件或中台服务等，不同层级的服务可能使用不同的协议，有不同的访问策略，并且可能重名，那么根据命名空间来划分就可以很方便地做一些区分管理。

  例如：`interface`、`service`、`infra`

<!-- ## 命名空间实践

我们团队在使用 k8s 时，结合当前的项目、团队、服务层级，创建了多个命名空间：
- `wesing-wns`：wns 团队使用
- `wesing-web`：web 团队使用
- `wesing-interface`：后台聚合服务层
- `wesing-service`：后台业务服务
- `wesing-infra`：后台中台服务或通用组件

由于我们的 k8s 集群已经区分了测试集群和正式集群，所以不需要用命名空间来区分环境。加项目前缀（`wesing-`）一方面是参考了 k8s 里命名空间的命名规范（`kube-public`、`kube-system`），另一方面是考虑到多个项目可能会部署在同一集群，加上项目前缀能做一定的区分。

整体上符合我们当前的服务架构：

![](image/2021-01-10-18-38-43.png) -->

## 命名空间使用技巧

使用 `kubectl config` 可以设置当前的命名空间的上下文，后续操作就不需要指定命名空间了。

```sh
kubectl config set-context --current --namespace=<命名空间名称>
```

也可以使用开源的 [kubectx](https://github.com/ahmetb/kubectx) 里的 `kubens` 工具，可以更方便地切换命名空间：

```sh
$ kubens kube-system
Context "test" set.
Active namespace is "kube-system".

$ kubens -
Context "test" set.
Active namespace is "default".
```

## 小结

本文介绍了 k8s 命名空间的概念以及使用方法，命名空间是一个非常简单又重要的概念，可以帮助团队更好的管理集群资源，熟悉命名空间的优点和特性可以帮助你更有效地配置集群，以避免后续带来的麻烦。
