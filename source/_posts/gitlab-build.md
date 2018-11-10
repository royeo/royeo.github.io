---
title: Gitlab 搭建与 CI 配置
date: 2018-11-10 17:21:57
category: 码梦为生
tags:
    - Gitlab
    - Golang
---

最近有一个独立开发的 Golang 微服务需要上线，项目托管在内部的 GitLab 上，所以需要写一个 `.gitlab-ci.yml` 文件来走 CI。由于之前一直是在比较成熟的团队中，没有自己写过 GitLab 的 CI 配置，所以索性尝试下自己搭建 GitLab，然后配置一套 CI 来熟悉下。

<!--more-->

## 搭建 GitLab

搭建 GitLab 最简单的方式当然是使用 docker。GitLab 的 docker 镜像集成了 GitLab 在运行中需要的所有服务。

这里使用 docker-compose 来运行，方便修改参数：

```sh
 web:
   image: 'gitlab/gitlab-ce:latest'
   restart: always
   hostname: 'gitlab.example.com'
   environment:
     GITLAB_OMNIBUS_CONFIG: |
       external_url 'https://gitlab.example.com'
       # Add any other gitlab.rb configuration here, each on its own line
   ports:
     - '80:80'
     - '443:443'
     - '22:22'
   volumes:
     - '/srv/gitlab/config:/etc/gitlab'
     - '/srv/gitlab/logs:/var/log/gitlab'
     - '/srv/gitlab/data:/var/opt/gitlab'
```

这里需要注意 SSH、HTTP、HTTPS 的端口是否被占用，以及卷的位置 docker 是否有权限访问。例如，在 macOS 上，docker 没有 `/srv` 的权限，所以可以使用 `/Users/Shared` 目录替代 `/srv`。

在容器启动后，等 GitLab 初始化完成（需等待一会），就可以通过  http://localhost/ 访问了。

另外还有一些部署 GitLab 的方法，具体参考官方文档：[Omnibus GitLab documentation](https://docs.gitlab.com/omnibus/README.html)。

## 配置 Gitlab

GitLab 的所有配置都在 `/etc/gitlab/gitlab.rb` 文件中，你可以在 docker 挂载的数据卷目录下去修改配置，也可以进入 docker 容器去修改：

```sh
docker exec -it gitlab /bin/bash
```

在 GitLab 的配置中，你需要修改 `external_url` 配置项为一个有效的 url，这个 url 就是你的 GitLab 仓库的域名，也可以通过上面 docker-compose 文件中的 `environment` 来修改 `external_url` 配置项。

还有很多其他的配置，如邮箱、HTTPS 等的配置就不多介绍了。详细配置参考官方文档：[Configuration options](https://docs.gitlab.com/omnibus/settings/configuration.html)。

在修改完配置后，需要重启 docker 容器：

```sh
docker restart gitlab
```

## 搭建 GitLab Runner

GitLab 的 CI 需要安装 Gitlab Runner，Runner 负责运行 `.gitlab-ci.yml` 中定义的 job，并且将结果发送回 GitLab。

Runner 不建议和 GitLab 同时运行在一台机器上，因为 Runner 很消耗资源，一旦 CI 运行起来，就可以看到 Runner 的 CPU 使用率飙升，所以应该分开部署。如果只是想测试一下，也可以先在一台机器上试一下。

同样使用 docker 来运行 Runner：

```sh
docker run -d --name gitlab-runner --restart always \
	-v /srv/gitlab-runner/config:/etc/gitlab-runner \
	-v /var/run/docker.sock:/var/run/docker.sock \
	gitlab/gitlab-runner:latest
```

然后需要把 Runner 注册到刚刚搭建好的 GitLab 上：

```sh
docker run --rm -t -i -v /srv/gitlab-runner/config:/etc/gitlab-runner --name gitlab-runner gitlab/gitlab-runner register \
  --non-interactive \
  --executor "docker" \
  --docker-image alpine:3.7 \
  --url "https://gitlab.com/" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --description "docker-runner" \
  --tag-list "docker,aws" \
  --run-untagged \
  --locked="false"
```

注册参数说明：

- --url：

	GitLab 的域名，如果还没有配置域名的话，可以先使用 IP 地址代替。

- --registration-token：

	CI 的 token，需要从 GitLab 页面上获取，参考：[Obtain a token](https://docs.gitlab.com/ee/ci/runners/)。

- --description

	Runner 的描述，稍后可以在 GitLab 的页面 Settings > CI/CD > Runners 那里看到该 Runner 的描述。

- --tag-list

	Runner 的 tags，使用 tag 标记 Runner 后，在 `.gitlab-ci.yml` 中定义 job 时，就可以使用 tags 配置来指定运行这个 job 的 Runner。

- --executor

	Runner 的执行器，推荐使用 docker，它拥有一个干净的构建环境，易于依赖管理。

- --docker-image

	如果你使用 docker 作为 executor，需要提供一个默认镜像，在 `.gitlab-ci.yml` 中没有定义镜像时使用。

## .gitlab-ci.yml

在搭建好 GitLab 和 Runner 后，就可以在 GitLab 上创建一个项目，然后写 CI 的配置文件 `.gitlab-ci.yml` 了，参考：[Configuring .gitlab-ci.yml](https://docs.gitlab.com/ee/ci/yaml/README.html)