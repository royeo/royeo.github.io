---
title: 如何更优雅地切换 Git 分支
date: 2019-02-01 14:04:41
tags:
    - Git
    - Golang
    - Tool
category: 码梦为生
---

在日常开发中，我们经常需要在不同的 Git 分支之间来回切换，特别是业务需求比较多的开发人员。在分支较多的情况下，切换分支时分支名的 tab 自动补全会比较糟糕，我们不免需要复制或手打分支名，那么有没有更优雅的方式了呢？

<!--more-->

为了提高切换 Git 分支的效率，我用 Golang 写了 `git-checkout-branch` 这个小工具，可以交互式的切换分支，并自带搜索功能，帮助你更优雅的进行分支切换。

## 概览

Github 地址：https://github.com/royeo/git-checkout-branch ，欢迎 star。

![](https://raw.githubusercontent.com/royeo/static/master/gif/git-checkout-branch.gif)

说明：
- 使用箭头键  `↓` `↑` `→` `←` 进行移动
- 使用 `j` 和 `k` 也可以上下移动
- 使用 `/` 切换搜索

## 安装

使用 `go get` 安装 `git checkout-branch` 命令，确保 `$GOPATH/bin` 路径在 `PATH` 中。

```sh
go get -u github.com/royeo/git-checkout-branch
```

如果你正在使用 GO1.11 Module，使用以下命令进行安装：

```sh
GO111MODULE=off go get -u github.com/royeo/git-checkout-branch
```

建议为 `checkout-branch` 设置别名，例如 `cb`，这样就可以直接使用 `git cb` 来进行分支切换。

```sh
git config --global alias.cb checkout-branch
```

## 帮助

使用 `git checkout-branch help` 获取帮助信息。

```sh
Checkout git branches more efficiently.

Usage:
  git checkout-branch [flags]

Flags:
  -a, --all          List both remote-tracking branches and local branches
  -r, --remotes      List the remote-tracking branches
  -n, --number       Set the number of branches displayed in the list (default 10)
      --hide-help    Hide the help information
```