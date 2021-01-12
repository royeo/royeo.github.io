---
title: k8s ImageGCFailed 问题排查
date: 2021-01-10 22:59:48
tags:
    - Kubernetes
    - Docker
category: 码梦为生
---

今天偶然发现 k8s 集群有节点异常，看了一下是磁盘压力 DiskPressure 异常，

立马去查看了一下异常事件：

```sh
$ kubectl describe node 9.131.136.14
...
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests          Limits
  --------           --------          ------
  cpu                7672m (32%)       28850m (120%)
  memory             8218011776 (12%)  34346400Ki (55%)
  ephemeral-storage  0 (0%)            0 (0%)
Events:
  Type     Reason                 Age                    From                   Message
  ----     ------                 ----                   ----                   -------
  Warning  FreeDiskSpaceFailed    34m                    kubelet, 9.131.136.14  failed to garbage collect required amount of images. Wanted to free 8094471782 bytes, but freed 0 bytes
  Normal   NodeHasNoDiskPressure  27m (x233 over 11d)    kubelet, 9.131.136.14  Node 9.131.136.14 status is now: NodeHasNoDiskPressure
  Warning  FreeDiskSpaceFailed    4m28s                  kubelet, 9.131.136.14  failed to garbage collect required amount of images. Wanted to free 9259128422 bytes, but freed 0 bytes
  Normal   NodeHasDiskPressure    3m4s (x232 over 11d)   kubelet, 9.131.136.14  Node 9.131.136.14 status is now: NodeHasDiskPressure
  Warning  EvictionThresholdMet   2m51s (x239 over 11d)  kubelet, 9.131.136.14  Attempting to reclaim ephemeral-storage
```

kubelet 可以清除未使用的容器和镜像。kubelet 在每分钟和每五分钟分别回收容器和镜像。但是 kubelet 的垃圾回收有个问题,它只能回收那些未使用的镜像,有点像 docker system prune,然而观察发现,那些死掉的容器不是最大的问题,正在运行的容器才是更大的问题.如果ImageGCFailed一直发生,而容器使用的ephemeral-storage/hostpath(宿主目录)越发增多,最终将会导致更严重的DiskPressure问题,波及节点上所有容器.

使用kubernetes的过程中，为了保持磁盘的空间在一个合理的使用率，kubele提供了垃圾回收机制，kubelet的垃圾回收机制分为镜像的回收和container的回收。

Kubelet 垃圾回收（Garbage Collection）是一个非常有用的功能，它负责自动清理节点上的无用镜像和容器。Kubelet 每隔 1 分钟进行一次容器清理，每隔 5 分钟进行一次镜像清理（截止到 v1.18版本，垃圾回收间隔时间还都是在源码中固化的，不可自定义配置）

我们可以在kubelet的源码src\k8s.io\kubernetes\pkg\kubelet\kubelet.go中看下这个时间的配置，其中定义了2个变量分别是ContainerGCPeriod 和ImageGCPeriod ，表示执行镜像和容器的垃圾回收间隔时间


新建或修改/etc/docker/daemon.json，添加log-dirver和log-opts参数

```sh
docker cat /etc/docker/daemon.json
{
  "bridge": "none",
  "debug": false,
  "default-runtime": "runc",
  "exec-opts": [],
  "exec-root": "",
  "graph": "/data/docker",
  "group": "",
  "insecure-registries": [],
  "ip-forward": true,
  "ip-masq": false,
  "iptables": false,
  "ipv6": false,
  "labels": [],
  "live-restore": true,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-file": "10",
    "max-size": "100m"
  },
  "max-concurrent-downloads": 10,
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com"
  ],
  "runtimes": {},
  "selinux-enabled": false,
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
```

```sh
sudo du -h --max-depth=1 /data
8.0K    /data/tlinux
3.3M    /data/L5Backup
148M    /data/services
4.0K    /data/filebeat
4.0K    /data/container2host
109G    /data/docker
456M    /data/elk_log
414M    /data/log
4.0K    /data/coredump
8.0K    /data/backup
8.7M    /data/home
12K     /data/tmp
40K     /data/dcagent
110G    /data
```

```sh
sudo du -h --max-depth=1 /data/docker
20K     /data/docker/plugins
1.8M    /data/docker/containerd
22M     /data/docker/image
4.0K    /data/docker/runtimes
12G     /data/docker/containers
72K     /data/docker/buildkit
124K    /data/docker/network
20K     /data/docker/builder
98G     /data/docker/overlay2
28K     /data/docker/volumes
4.0K    /data/docker/swarm
4.0K    /data/docker/tmp
4.0K    /data/docker/trust
109G    /data/docker
```

```sh
 sudo du -h --max-depth=1 /data/docker
20K     /data/docker/plugins
1.8M    /data/docker/containerd
22M     /data/docker/image
4.0K    /data/docker/runtimes
11G     /data/docker/containers
72K     /data/docker/buildkit
128K    /data/docker/network
20K     /data/docker/builder
110G    /data/docker/overlay2
28K     /data/docker/volumes
4.0K    /data/docker/swarm
4.0K    /data/docker/tmp
4.0K    /data/docker/trust
121G    /data/docker
```

```sh
sudo du -h --max-depth=1 /    
0       /proc
0       /dev
4.0M    /run
1.2G    /var
0       /sys
110G    /data
39M     /etc
4.0K    /srv
260K    /tke_init
5.5G    /usr
344K    /home
768K    /root
119M    /boot
4.0K    /media
16K     /lost+found
259M    /tmp
136M    /opt
4.0K    /mnt
117G    /
```


```sh
[davinlu@Tencent-SNG ~]$ sudo du -h --max-depth=1 /data/docker/overlay2 | sort -hr | head -n 10
111G    /data/docker/overlay2
12G     /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d
11G     /data/docker/overlay2/ec393bc526b0d0f5190b5087285154864b0795d3bfef6766bdd929b4dfb784b4
11G     /data/docker/overlay2/a182d7d2519796bc3cce9428570bbf162bc5d27b1e1599a1f877310099f47508
11G     /data/docker/overlay2/90e353bff0789834386bdd51bc91a52adba385640eb6b5a43e02b54804828b8b
11G     /data/docker/overlay2/8c1e7d3b9f761f6bfdf84cd0ef8739d2a50abb87abec686a563a377bb572a17d
11G     /data/docker/overlay2/636a16a6a7ab6e070edcb0887d820b3ca418edea4b32f10d9cb790bfd9e86dad
9.9G    /data/docker/overlay2/0469ee7b448fa75ed2abf08f31faa87c63a384e611aa350a788a31fb01ea8c0d
7.2G    /data/docker/overlay2/6fbc9e34b1cab473dbf5e8fcca4f63b95fb5ab0bc9de867b37aaaa3c1ea776e1
6.0G    /data/docker/overlay2/1f5b61bac31f3f10b600d13f90fcf27f9e82a3747feb2d282e910e3889223fa0
```


```sh
[davinlu@Tencent-SNG ~]$ sudo du -h --max-depth=1 /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d | sort -hr | head -n 10
12G     /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d
6.2G    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged
5.0G    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/diff
8.0K    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/work
```

```sh
[davinlu@Tencent-SNG ~]$ sudo du -h --max-depth=1 /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged | sort -hr | head -n 10
6.2G    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged
4.9G    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/log
1.1G    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/usr
112M    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/var
92M     /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/polaris
21M     /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/etc
604K    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/boot
368K    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/root
108K    /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/run
32K     /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/tmp
```

```sh
[davinlu@Tencent-SNG ~]$ sudo ls -lh /data/docker/overlay2/a5428948afb388c495ce0e0f3e5779248030a1f9425706675b3b3a226e16b02d/merged/log
total 4.9G
-rw-r--r-- 1 root root 622M Jan  4 23:59 going.2021-01-04.log
-rw-r--r-- 1 root root 526M Jan  5 23:59 going.2021-01-05.log
-rw-r--r-- 1 root root 439M Jan  6 23:59 going.2021-01-06.log
-rw-r--r-- 1 root root 526M Jan  7 23:59 going.2021-01-07.log
-rw-r--r-- 1 root root 517M Jan  8 23:59 going.2021-01-08.log
-rw-r--r-- 1 root root 771M Jan  9 23:59 going.2021-01-09.log
-rw-r--r-- 1 root root 182M Jan 10 23:59 going.2021-01-10.log
-rw-r--r-- 1 root root 1.1G Jan 10 21:46 going.2021-01-10.log.full.1.log
-rw-r--r-- 1 root root 374M Jan 11 11:02 going.2021-01-11.log
-rw-r--r-- 1 root root  12M Jan 11 11:02 stat.log
```
