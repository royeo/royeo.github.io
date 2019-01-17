---
title: 如何写一个 golang 日志库
date: 2018-12-05 23:41:10
tags:
---

Golang 的日志库有很多，例如：logrus、gokit 的 log、uber 的 zap 等，在观察了这几个比较流行的日志库后，决定自己造一个日志库的轮子。

## 日志设计

设计一个好的日志库首先需要考虑以下几个问题：

1. 日志格式
2. 日志级别
3. 并发安全
2. 性能问题

接下来我们一个个来讨论。

### 日志格式

常见的日志格式分为两种：
- 非结构化的：字符串形式
- 结构化的：JSON形式、logfmt形式

#### 非结构化的日志

非结构化的日志通常记录一个字符串，或者是类似 fmt.Printf 的格式化输出，如：

```go
log.Printf("something happened: %v", "unknown error")

// Output:
// 2018/12/07 20:05:50 something happened: unknown error
```

使用非结构化日志的问题在于，每次写日志都需要硬编码一个特定的字符串，没有一个固定的格式，也难以被其他程序解析。

#### 结构化的日志

结构化的日志记录通常使用 JSON 格式或 Logfmt 格式

### 日志级别

日志级别用于标识事件的严重性，同时也可以过滤日志的输出。

在实际项目开发中，我们经常需要写不同级别的日志，比如调试的时候我们会写 debug 日志，错误处理时我们会写 error 日志。并且，在开发环境中，我们希望能输出所有级别的日志，而在生产环境中，我们一般只希望输出 error 日志。

这里我们首先要了解下有哪些日志级别，参考 [log4j](https://logging.apache.org/log4j/2.x/) 日志库，log4j 定义了8种日志级别：

|级别|描述|
|-|-|-|
|ALL    |记录所有事件|
|TRACE  |比 DEBUG 粒度更细的事件，用于调试应用程序|
|DEBUG  |细粒度的事件，用于调试应用程序|
|INFO   |粗粒度的事件，用于显示应用程序的进度|
|WARN   |可能导致错误的事件|
|ERROR  |错误事件，但应用程序可能还能继续运行|
|FATAL  |严重的错误事件，可能会导致应用程序终止运行|
|OFF    |不会记录任何事件|

上面的日志级别从低到高排序，ALL 级别最低，OFF 级别最高。log4j 建议只使用四个级别，分别是 DEBUG、INFO、WARN、ERROR，一般项目里常用的也就这几个。

当你设置了一个日志级别之后，只有比这个级别高的或者相等的日志才会输出。例如，如果设置当前的日志级别为 WARN，那么 OFF、FATAL、ERROR、WARN 4个级别的日志能正常输出，而 INFO、DEBUG、TRACE、 ALL 级别的日志则会被忽略。

下面使用 Logrus 的例子来展示如何过滤 DEBUG 和 INFO 级别的日志，使用 `log.SetLevel(log.X)` 来设置期望的日志级别。

```go
package main

import log "github.com/sirupsen/logrus"

func main() {
	log.SetLevel(log.WarnLevel)

	log.Trace("Trace Message!")
	log.Debug("Debug Message!")
	log.Info("Info Message!")
	log.Warn("Warn Message!")
	log.Error("Error Message!")
	log.Fatal("Fatal Message!")
}
```

运行程序后打印出：

```sh
WARN[0000] Warn Message!
ERRO[0000] Error Message!
FATA[0000] Fatal Message!
```

### 并发安全

asd

### 性能问题


Golang 的log包内容不多，说实话，直接用来做日志开发有些简易。主要是缺少一些功能：
按日志级别打印和控制日志；
日志文件自动分割；
异步打印日志。

## 开始造轮子

首先我们需要定义一个日志的结构体：

```go
type Logger struct {
    level int
    buf []byte
}
```

我们实现的日志库将会支持4个常用的日志级别：

```go
type Level byte

const (
	LevelDebug Level = 1 << iota
	LevelInfo
	LevelWarn
	LevelError
)

func (l *Logger) SetLevel(level Level) {
	l.mu.Lock()
	l.level = level
	l.mu.Unlock()
}
```

## 参考

- [Log4j - Wiki](https://en.wikipedia.org/wiki/Log4j)