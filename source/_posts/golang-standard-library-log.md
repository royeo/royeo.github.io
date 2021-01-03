---
title: Golang 标准库 log 包
date: 2019-01-18 10:06:54
tags:
	- Golang
	- Log
category: 码梦为生
---

Golang 标准库提供了一个简单的 log 包，方便我们记录日志。在平时写一些 demo 或小程序时，我们经常会用到 log 包，不过由于缺少结构化格式、日志级别等支持，在实际开发中则很少使用。log 包的设计非常简洁，造轮子之前可以参考下。

<!--more-->

## 日志设计

一个简单的日志包应该有哪些功能呢？很容易想到以下几个：
- 可设置日志的输出目标
- 可设置日志的固定输出项
- 日志输出接收可变参数
- 输出日志时并发安全

所以标准库的 log 里设计了下面这样一个 `Logger` 结构体：

```go
// log.go
type Logger struct {
	mu     sync.Mutex // ensures atomic writes; protects the following fields
	prefix string     // prefix on each line to identify the logger (but see Lmsgprefix)
	flag   int        // properties
	out    io.Writer  // destination for output
	buf    []byte     // for accumulating text to write
}
```

`out` 属性是日志的输出目标，在 golang 中，很自然的可以想到使用 `io.Writer` 接口，与具体实现分离开。之所以不把 `out` 属性暴露出来，是因为需要保证 `out` 的写入和修改都是原子操作，其他属性同理。这里使用 `sync.Mutex` 互斥锁来保证原子操作：

```go
// log.go
func (l *Logger) SetOutput(w io.Writer) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.out = w
}
```

`prefix` 会出现在每行日志的最开头，`flag` 则是紧随其后的一些日志记录属性，如日期、时间、文件名和行号等。当设置了 `prefix` 和 `flag` 之后，每一行输出的日志都会带上这些前缀。`flag` 通过按位或（`|`）的方式来设置多个属性，可设置的属性如下：

```go
// log.go
const (
	Ldate         = 1 << iota     // the date in the local time zone: 2009/01/23
	Ltime                         // the time in the local time zone: 01:23:23
	Lmicroseconds                 // microsecond resolution: 01:23:23.123123.  assumes Ltime.
	Llongfile                     // full file name and line number: /a/b/c/d.go:23
	Lshortfile                    // final file name element and line number: d.go:23. overrides Llongfile
	LUTC                          // if Ldate or Ltime is set, use UTC rather than the local time zone
	Lmsgprefix                    // move the "prefix" from the beginning of the line to before the message
	LstdFlags     = Ldate | Ltime // initial values for the standard logger
)
```

`buf` 是日志写入内容的缓冲区，避免了每次写入都需要分配内存。

## 日志操作

使用 log 包写日志的操作很简单，可以直接调用 `log.Println`，`log.Printf` 等函数，这些导出的函数会调用内部私有变量 `std` 的方法，`std` 是 `Logger` 结构体的一个实例，输出日志到 `stderr`。在包里定义一个私有的 `Logger` 实例，并进行一些通用的配置，可以提供一些开箱即用的函数，而不需要总是先 `New` 一个 `Logger` 实例。

```go
// log.go
func New(out io.Writer, prefix string, flag int) *Logger {
	return &Logger{out: out, prefix: prefix, flag: flag}
}

var std = New(os.Stderr, "", LstdFlags)

func Println(v ...interface{}) {
	std.Output(2, fmt.Sprintln(v...))
}
```

可以看到 `log.Println` 实际调用了 `std.Output` 方法，该方法接收两个参数，一个是函数调用深度，一个是日志内容。

```go
// log.go
func (l *Logger) Output(calldepth int, s string) error {
	now := time.Now() // get this early.
	var file string
	var line int
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.flag&(Lshortfile|Llongfile) != 0 {
		// Release lock while getting caller info - it's expensive.
		l.mu.Unlock()
		var ok bool
		_, file, line, ok = runtime.Caller(calldepth)
		if !ok {
			file = "???"
			line = 0
		}
		l.mu.Lock()
	}
	l.buf = l.buf[:0]
	l.formatHeader(&l.buf, now, file, line)
	l.buf = append(l.buf, s...)
	if len(s) == 0 || s[len(s)-1] != '\n' {
		l.buf = append(l.buf, '\n')
	}
	_, err := l.out.Write(l.buf)
	return err
}
```

如果 `flag` 设置了 `Lshortfile` 或 `Llongfile` 属性，`Output` 方法会调用 `runtime.Caller` 来获取打印日志操作所在的文件名和行号。`calldepth` 参数用来指定函数调用深度，调用链为：`log.Println` -> `std.Output` -> `runtime.Caller`，所以调用深度为2。注意这里在获取文件名和行号的时候，释放了互斥锁，原因是 `runtime.Caller` 可能会比较耗时，所以存在一个隐患：在这期间其他的 goroutine 是可以修改 `Logger` 实例的属性的。

接下来就是清空 `buf`，先对 `prefix` 和 `flag` 进行处理（`l.formatHeader`）并存入 `buf`，然后将日志内容也追加到 `buf` 中，最后调用 `out` 属性的 `Write` 方法输出日志。

## 结论

整个 log 包就 300 多行代码，功能非常简单，使用起来也很方便。对于标准库来说，考虑的更多的是简洁、通用，而对于后端服务来说，则需要考虑更多的东西，比如结构化日志、性能问题等。一般情况下，不建议在生产环境使用标准库的 log 包来输出日志。目前 Golang 有很多优秀的开源日志库，例如：`zap`、`gokit/log`、`logrus` 等，各有各的优势，我们可以针对不同场景选择不同的日志库来解决问题，或者自行造轮子。另外，在使用日志库的时候，最好是能够使用一个日志的抽象（比如 interface），而不绑定具体的实现，这会方便我们后期更换其他日志库。
