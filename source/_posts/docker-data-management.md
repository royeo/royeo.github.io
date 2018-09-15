---
title: Docker 数据管理
date: 2018-09-15 15:13:53
category: 码梦为生
tags:
    - Docker
---

Docker 提供了3种方式将数据从Docker宿主机挂载到容器：

- Volumes
- Bind mounts
- tmpfs mounts

一般来说，volumes总是最好的选择。

<!--more-->

## 容器写入层的缺点

我们可以将数据写到容器的可写入层，但是这种写入是有缺点的：

- 当容器停止运行时，写入的数据会丢失。你也很难将这些数据从容器中取出来给另外的应用程序使用。

- 容器的可写入层与宿主机是紧密耦合的。这些写入的数据在可以轻易地被删掉。

- 写入容器的可写入层需要一个存储驱动（storage driver）来管理文件系统。这个存储驱动通过linux内核提供了一个union filesystem。相比于数据卷（data volume），这种额外的抽象会降低性能。

## 选择合适的挂载方式

不管你选择哪种挂载方式，从容器中看都是一样的。数据在容器的文件系统中被展示为一个目录或者一个单独的文件。

一个简单区分 volumes，bind mounts 和 tmpfs mounts 不同点的方法是：思考数据在宿主机上是如何存在的。

![image](https://michaelyou.github.io/img/types-of-mounts.png)

Volumes 由 Docker 管理，存储在宿主机的某个地方（在 linux 上是 `/var/lib/docker/volumes/`）。非 Docker 应用程序不能改动这一位置的数据。Volumes 是 Docker 最好的数据持久化方法。

- Volumes 由 Docker 创建和管理。你可以通过 `docker volume create` 命令显式地创建 volume，Docker 也可以在创建容器或服务是自己创建 volume。
    
- 当你创建了一个 volume，它会被存放在宿主机的一个目录下。当你将这个 volume 挂载到某个容器时，这个目录就是挂载到容器的东西。这一点和 bind mounts 类似，除了 volumes 是由 Docker 创建的，和宿主机的核心（core functionality）隔离。
    
- 一个 volume 可以同时被挂载到几个容器中。即使没有正在运行的容器使用这个 volume，volume 依然存在，不会被自动清除。可以通过 `docker volume prune` 清除不再使用的 volumes。
    
- volumes 也支持 volume driver，可以将数据存放在另外的机器或者云上。

Bind mounts 的数据可以存放在宿主机的任何地方。数据甚至可以是重要的系统文件或目录。非 Docker 应用程序可以改变这些数据。

- Docker 早期就支持这个特性。与 volumes 相比，Bind mounts 支持的功能有限。使用 bind mounts 时，宿主机上的一个文件或目录被挂载到容器上。
    
- 警告：使用 Bind mounts 的一个副作用是，容器中运行的程序可以修改宿主机的文件系统，包括创建，修改，删除重要的系统文件或目录。这个功能可能会有安全问题。

tmpfs mounts 的数据只存储在宿主机的内存中，不会写入到宿主机的文件系统。

- tmpfs mounts 的数据不会落盘。在容器的生命周期内，它可以被用来存储一些不需要持久化的状态或敏感数据。例如，swarm 服务通过 tmpfs mounts 来将 secrets 挂载到一个服务的容器中去。

### 适合Volumes的场景

- 在不同的容器中共享数据。

- 当 Docker 主机不能保证具有给定的目录或文件结构时，Volumes 可帮助你将 Docker 主机的配置与容器运行时分离。

- 当要将容器的数据存储在远程主机或云提供程序上的时候。

- 当你需要备份或迁移数据的时候。

### 适合bind mounts的场景

- 宿主机和容器共享配置文件。Docker 提供的 DNS 解决方案就是如此，将宿主机的 `/etc/resolv.conf` 挂载到每个容器中。

- 开发环境需要在宿主机和容器中共享代码。docker 的开发就是如此，毕竟容器中一般是没有编辑器的。

- 当 Docker 主机的文件或目录结构保证与容器所需的绑定装载一致时。

### 适合tmpfs mounts的场景

- tmpfs mounts 主要用在你既不想在容器内，又不想在宿主机文件系统保存数据的时候。这可能是出于安全原因，也可能是你的应用需要写非常多的非持久化数据，tmpfs mounts 这时候可以保证容器性能。
