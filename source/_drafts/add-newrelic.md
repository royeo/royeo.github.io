---
title: 在 Node 应用中部署 New Relic
date: 2017-04-12 21:25:16
tags: 
    - Node.js
    - APM
category: 码梦为生
---

[New Relic](https://newrelic.com/) 是一个很强大的应用性能监控工具，目前专注于SaaS和App性能管理业务，它支持支持agent和API传送数据，能够对部署在本地或在云中的web应用程序进行监控、故障修复、诊断、线程分析以及容量计划。

文档：https://docs.newrelic.com/docs/agents/nodejs-agent

一. 注册帐号

https://newrelic.com/signup

获取自己的 `license key`：


二. 安装 New Relic

1. 首先要确保满足 New Relic 的[系统要求](https://docs.newrelic.com/docs/agents/nodejs-agent/getting-started/compatibility-requirements-nodejs-agent)，尤其是要确认你正在使用的 Node 版本是否受支持。

2. 在要监控的项目里安装 newrelic：

    ```bash
    npm install newrelic --save
    ```

3. 把 `node_modules/newrelic` 目录下的 `newrelic.js` 拷贝到项目的根目录，并编辑 `newrelic.js`，设置 `license_key` 为自己的 `license key`，然后设置一个有意义的 `app_name`。

4. 在程序入口文件的第一行加上：

    ```js
    require('newrelic');
    ```

5. 重启项目