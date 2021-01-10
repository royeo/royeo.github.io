---
title: k8s ImageGCFailed 问题排查
date: 2021-01-10 22:59:48
tags:
    - Kubernetes
    - Docker
category: 码梦为生
---

今天偶然发现 k8s 集群有节点异常，看了一下是磁盘压力，立马去查看了一下异常事件，发现 Node 上有大量的 ImageGCFailed 事件，详细描述如下：

```sh
(combined from similar events): failed to garbage collect required amount of images. Wanted to free 7035291238 bytes, but freed 0 bytes
```

使用kubernetes的过程中，为了保持磁盘的空间在一个合理的使用率，kubele提供了垃圾回收机制，kubelet的垃圾回收机制分为镜像的回收和container的回收。

Kubelet 垃圾回收（Garbage Collection）是一个非常有用的功能，它负责自动清理节点上的无用镜像和容器。Kubelet 每隔 1 分钟进行一次容器清理，每隔 5 分钟进行一次镜像清理（截止到 v1.18版本，垃圾回收间隔时间还都是在源码中固化的，不可自定义配置）

我们可以在kubelet的源码src\k8s.io\kubernetes\pkg\kubelet\kubelet.go中看下这个时间的配置，其中定义了2个变量分别是ContainerGCPeriod 和ImageGCPeriod ，表示执行镜像和容器的垃圾回收间隔时间

