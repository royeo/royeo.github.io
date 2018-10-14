---
title: URL中的#号
date: 2018-10-25 15:52:53
tags: URL
category: 码梦为生
---

今天用 postman 调试一个 GET 接口，接口 url 的 query 中有一个 color 参数，如：`http://example.com/?color=#ffffff`。请求一下失败了，查看日志发现后端接收到 URL 很奇怪，# 号及其后面的所有字符都消失了，如：`http://example.com?color=`。因为对 URL 中的 # 没什么了解，然后就去查了下资料，下面整理了一些 # 号相关的资料。

## 《HTTP权威指南》中的描述

《HTTP权威指南》称 URL 中的 # 号为片段：

> 为了引用部分资源或资源的一个片段，URL 支持使用片段（frag）组件来表示一个资源内部的片段。比如，URL 可以指向 HTML 文档中一个特定的图片或小节。


> HTTP 服务器通常只处理整个对象，而不是对象的片段，客户端不能将片段传送给服务器。浏览器从服务器获得了整个资源之后，会根据片段来显示你感兴趣的那部分资源。

这样就清楚了，原来是客户端或浏览器在请求的时候，对 # 号做了处理，


## #的含义

#代表网页中的一个位置。其右面的字符，就是该位置的标识符。比如：

```url
http://www.example.com/index.html#print
```

就代表网页index.html的print位置。浏览器读取这个URL后，会自动将print位置滚动至可视区域。

为网页位置指定标识符，有两个方法。一是使用锚点，比如 `<a name="print"></a>` ，二是使用id属性，比如 `<div id="print" >` 。

## HTTP请求不包括#

#是用来指导浏览器动作的，对服务器端完全无用。所以，HTTP请求中不包括#。

比如，访问下面的网址，

```
http://www.example.com/index.html#print
```

浏览器实际发出的请求是这样的：

```
GET /index.html HTTP/1.1
Host: www.example.com
```

可以看到，只是请求index.html，根本没有"#print"的部分。

## #后的字符

在第一个#后面出现的任何字符，都会被浏览器解读为位置标识符。这意味着，这些字符都不会被发送到服务器端。
比如，下面URL的原意是指定一个颜色值：

```
http://www.example.com/?color=#fff
```

但是，浏览器实际发出的请求是：

```
GET /?color= HTTP/1.1
Host: www.example.com/?color=
```

可以看到，"#fff"被省略了。只有将#转码为%23，浏览器才会将其作为实义字符处理。也就是说，上面的网址应该被写成：

```
http://example.com/?color=%23fff
```

## 改变#不触发网页重载

单单改变#后的部分，浏览器只会滚动到相应位置，不会重新加载网页。

比如，从

```
http://www.example.com/index.html#location1
```

改成

```
http://www.example.com/index.html#location2
```

浏览器不会重新向服务器请求index.html。

## 改变#会改变浏览器的访问历史

每一次改变#后的部分，都会在浏览器的访问历史中增加一个记录，使用"后退"按钮，就可以回到上一个位置。

这对于ajax应用程序特别有用，可以用不同的#值，表示不同的访问状态，然后向用户给出可以访问某个状态的链接。

值得注意的是，上述规则对IE 6和IE 7不成立，它们不会因为#的改变而增加历史记录。

