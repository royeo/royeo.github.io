---
title: Protocol Buffer 介绍
date: 2018-06-02 02:39:05
tags: Protocol Buffer
category: 码梦为生
---

`protocol buffer` 是一种语言无关，平台无关，可扩展的序列化结构化数据的方式，用于通信协议，数据存储等。

<!--more-->

`protocol buffer` 目前支持Java，Python，Objective-C 和 C++ 中的生成代码。使用新的 `proto3` 语言版本，您还可以使用 Go，Ruby 和 C＃ 等更多语言。

## 为什么选择 Protocol Buffer ？

通常我们定义好的请求和响应在客户端和服务端都需要手动编码/解码，但是随着接口的版本变化，可能需要对版本号进行判断才能做相应的处理。这样使得新的协议变得复杂，因为开发者必须确保请求发起者与处理请求的实际服务器之间的所有服务器都能理解新协议，然后才能开始使用新协议。

`protocol buffer` 旨在解决这些问题：

- 可以很容易地引入新的字段，中间服务器可以简单地解析并传递数据，而无需了解所有字段。

- 协议格式的描述性更强，可以用各种语言来处理（C ++，Java等），并且速度更快，空间更小。

## 开始使用

开始使用 `protocol buffer` 的第一步，就是创建一个 `.proto` 文件来定义 `protocol buffer` 消息类型，指定你想要序列化的信息结构。

每个 `protocol buffer` 消息是一个小的逻辑信息记录，包含一系列 `name-value` 对。下面是 `.proto` 文件的一个例子，定义了一条包含人员信息的消息：

```
message Person {
  required string name = 1;
  required int32 id = 2;
  optional string email = 3;

  enum PhoneType {
    MOBILE = 0;
    HOME = 1;
    WORK = 2;
  }

  message PhoneNumber {
    required string number = 1;
    optional PhoneType type = 2 [default = HOME];
  }

  repeated PhoneNumber phone = 4;
}
```

正如你所看到的，消息格式很简单。每种消息类型（如 `message Person`）都有一个或多个带有唯一编号的字段，每个字段都有一个名称和一个值类型。其中值类型可以是数字（整数或浮点数），布尔值，字符串，原始字节，甚至可以是其他 `protocol buffer` 的消息类型。在消息类型中，你可以指定可选字段，必填字段和重复字段。访问 [Protocol Buffer Language Guide](https://developers.google.com/protocol-buffers/docs/proto3) 以获取更多有关 `.proto` 文件的信息。

当在 `.proto` 文件中定义完消息后，你需要运行 `protocol buffer` 编译器为你使用的编程语言生成数据访问类。这为每个字段提供了简单的访问器（如 `name()` 和 `set_name()`），以及对整个结构的进行序列化/解析的方法。例如，如果您选择的语言是 `C++`，那么在上面的示例中运行编译器将生成一个名为 `Person` 的类。然后，就可以在应用程序中使用此类来填充，序列化并检索 `Person` `protocol buffer` 消息。你可能会写下如下代码：

```c++
Person person;
person.set_name("John Doe");
person.set_id(1234);
person.set_email("jdoe@example.com");
fstream output("myfile", ios::out | ios::binary);
person.SerializeToOstream(&output);
```

然后，可以通过以下方式读取消息：

```c++
fstream input("myfile", ios::in | ios::binary);
Person person;
person.ParseFromIstream(&input);
cout << "Name: " << person.name() << endl;
cout << "E-mail: " << person.email() << endl;
```

你可以将新字段添加到消息格式中，而不会破坏向后兼容性; 解析时旧的二进制文件会简单地忽略新字段。所以如果你有一个使用 `protocol buffer` 作为数据格式的通信协议，你可以扩展你的协议，而不用担心破坏现有的代码。

详细的 `protocol buffer` 介绍以及使用请参考 [官方文档](https://developers.google.com/protocol-buffers/)。
