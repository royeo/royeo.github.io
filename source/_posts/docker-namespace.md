---
title: docker-namespace
date: 2021-01-12 22:31:36
tags:
---

# Docker 容器 Namespace 初探 

Docker 容器就像一个沙盒，把应用程序装起来，让应用程序与外界隔离开，互不干扰。那么 docker 容器是怎么实现这样的隔离的呢，我们来看一下。

## 容器的资源隔离

思考一下，如果要实现一个资源隔离的容器，应该从哪里开始下手呢？首先容器要有自己的根目录挂载点，所以需要隔离文件系统。接着考虑到容器里的用户权限问题，就需要隔离用户和用户组。然后运行在容器中的进程需要有进程号，要跟宿主机的进程号隔离开。为了和其他应用进行通信，容器也要有自己的 IP、端口等，所以网络也要隔离。网络隔离了，自然就会想到进程间通信也需要隔离。另外容器还需要一个独立的主机名用来在网络中标识自己，所以主机名也需要隔离。

总结一下容器需要的隔离：
- 文件系统隔离
- 用户隔离
- 进程号隔离
- 网络隔离
- 进程间通信隔离
- 主机名与域名隔离

Linux 内核中提供了这 6 种 namespace 隔离的系统调用：

|namespace|系统调用参数|隔离内容|
|-|-|-|
|UTS|CLONE_NEWUTS|主机名和域名|
|IPC|CLONE_NEWIPC|信号量、消息队列和共享内存|
|PID|CLONE_NEWPID|进程号|
|Network|CLONE_NEWNET|网络设备、网络栈、端口等|
|Mount|CLONE_NEWNS|挂载点（文件系统）|
|User|CLONE_NEWUSER|用户和用户组|

众所周知，在 Linux 中创建进程的系统调用是 `clone()`，这个系统调用会为我们创建一个新的进程，并且返回它的进程号：

```c
int clone(int (*child_func)(void *), void *chlid_stack, int flags, void *args);
```

而 Linux namespace 其实就是 Linux 创建进程的一个可选参数，例如在参数中指定 `CLONE_NEWPID`，那么新创建的进程在新的进程空间里就会看到它自己的 PID 是 1。但本质上它还是宿主机上的进程，所以这个进程在宿主机上依然有一个对应的 PID。

```c
int pid = clone(main_function, stack_size, CLONE_NEWPID | SIGCHLD, NULL); 
```

用 docker 容器来实际看一下，首先我们来创建一个容器，容器的启动进程是 shell：

```sh
docker run -it busybox sh
```

在容器里执行 ps 命令，就会发现容器里一共有两个进程在运行，而最开始执行的 sh 就是1号进程。这就说明，容器里的进程 PID 已经和宿主机之间隔离开了。

```sh
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 sh
    6 root      0:00 ps
```

因为容器本质上还是宿主机上的进程，所以容器里的进程在宿主机里还是拥有一个进程号的，用 `docker top <container_id>` 来查看，可以看到容器里的 sh 进程在宿主机上的 PID 为 28098。

```sh
$ docker top ce61cf4c1804
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
root                28098               28077               0                   21:05               pts/0               00:00:00            sh
```

## 小结

对于 docker 来说，一个运行中的 docker 容器，其实就是在宿主机上的一个启动了多个 namespace 的进程，另外这个进程使用的资源受到 cgroups 的限制。所以说白了，容器其实就是一种特殊的进程而已。

接下来我们详细看一下这几个 Linux namespace 的隔离。

### PID namespace

### IPC namespace

### Mount namespace


### Network namespace

### User namespace

user namespace 隔离了用户ID、用户组ID。

User namespace 是 Linux 3.8 新增的一种 namespace，用于隔离安全相关的资源，包括 user IDs and group IDs，keys, 和 capabilities。同样一个用户的 user ID 和 group ID 在不同的 user namespace 中可以不一样(与 PID nanespace 类似)。换句话说，一个用户可以在一个 user namespace 中是普通用户，但在另一个 user namespace 中是超级用户。


这就可以实现，一个进程在容器外属于一个没有权限的普通用户，而在容器内就属于 root 用户。

User Namespace 提供的隔离机制允许多个不同的进程间各有自己独立的一套 UID/GID 体系，并且可以将进程内部的 UID/GID 与宿主机的 UID/GID 进行映射。至于 UID/GID 的映射，可以在/proc/<pid>/uid_map 和 /proc/<pid>/gid_map 两个文件中，按照 ID-inside-ns ID-outside-ns length的形式写入映射记录。

这里有一个实现进程间「安全机制」的 Case，是通过 Linux User Namespace 来实现的:

在创建子进程的时候，父进程通过对/proc/<子进程pid>/uid_map 和 /proc/<子进程pid>/gid_map 两个文件的写入，将子进程的PID 映射为子进程内部值为0的 uid 和 gid。子进程启动的时候，会因为我们设置了 uid 为0，从而自动切换到 root 用户。这样一来，我们就实现了使用一般用户创建子进程，但是在子进程的内部确是以 root 用户的身份来运行的效果。

