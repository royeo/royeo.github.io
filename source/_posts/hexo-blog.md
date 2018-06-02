---
title: Hexo 博客搭建 
date: 2016-06-19 23:11:39
tags: 博客搭建
category: 码梦为生
---

作为一名开发人员，一直以来都很想拥有一个个人博客，来和世界分享自己的所见所得。在了解 hexo 后，惊叹于 hexo 搭建个人博客的快速、高效，以及各类丰富的博客主题。千挑万选之下选择了十分简洁大气的 maupassant-hexo 主题，下面是我搭建 maupassant-hexo 主题博客的全过程。

<!--more-->

## 安装 Hexo

安装前提：
- Node.js
- Git

使用 npm 进行 hexo 的全局安装：

```bash
npm install -g hexo-cli
```

创建 Hexo 根目录，`<folder>`为目录名：

```bash
hexo init <folder>
```

进入 Hexo 根目录，通过`hexo server`命令启动服务器，默认的访问地址是：`http://localhost:4000`，然后就可以看到 hexo 默认主题的页面。

## 安装 maupassant-hexo 主题

在 Hexo 根目录下执行下面的命令，安装主题和渲染器：

```bash
git clone https://github.com/tufu9441/maupassant-hexo.git themes/maupassant
npm install hexo-renderer-jade@0.3.0 --save
npm install hexo-renderer-sass --save
```

编辑 Hexo 根目录下的`_config.yml`，将`theme`的值改为`maupassant`，然后就可以删除`themes`目录下的默认主题`landscape`了。 

> 注：如果 `npm install hexo-renderer-sass` 安装时报错，可能是国内网络问题，请尝试使用代理或者切换至淘宝NPM镜像安装。

然后在 Hexo 根目录下执行`hexo server`命令，就可以访问到`maupassant-hexo`主题的页面了。到此本地的博客就算搭建完成了，进一步的配置参考官方文档：
- [Hexo 配置](https://hexo.io/zh-cn/docs/configuration.html)
- [maupassant-hexo 中文文档](https://www.haomwei.com/technology/maupassant-hexo.html)

## 基本操作

### # 添加文章

```bash
hexo new [layout] <title>
```

如果没有设置 layout 的话，默认使用`_config.yml`中的`default_layout`参数代替。如果标题包含空格的话，请使用引号括起来。新建的文章存放在 Hexo 根目录的`source/_posts`下，也可以手动在`source/_posts`目录下添加文章。

### # 添加分类 / 标签

在 [Front-matter](https://hexo.io/zh-cn/docs/front-matter.html) 中添加`categories`或`tags`的配置，在右边的侧边栏就会添加对应的分类或标签。

```
---
title: Hexo 博客搭建 
date: 2017-07-19 23:11:39
tags: 博客搭建
category: 技术
---
```

### # 添加 RSS 订阅功能

在 Hexo 根目录下执行下面命令，安装`hexo-generator-feed`:

```bash
npm install hexo-generator-feed --save 
```

在 Hexo 根目录下的`_config.yml`中添加 RSS 订阅的配置：

```bash
feed:
  type: atom
  path: atom.xml
  limit: 20
```

### # 删除友情链接

注释主题目录下`_config.yml`中友情链接的配置，如下：

```yml
# links:
#   - title: site-name1
#     url: http://www.example1.com/
#   - title: site-name2
#     url: http://www.example2.com/
#   - title: site-name3
#     url: http://www.example3.com/
```

### # 更换中文

编辑 Hexo 根目录下的`_config.yml`，将`language`设置为`zh-CN`。






