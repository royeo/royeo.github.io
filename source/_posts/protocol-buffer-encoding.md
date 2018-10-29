---
title: Protocol Buffer Encoding
date: 2018-06-03 06:02:17
tags: Protocol Buffer
category: 码梦为生
---

> 本文翻译自： https://developers.google.com/protocol-buffers/docs/encoding

本文档介绍了 protocol buffer message 的二进制格式。你不需要知道这个就可以在你的应用程序中使用 protocol buffer，但如果你想了解 protocol buffer 格式对编码后的 message 大小的影响，该文档非常有用。

<!--more-->

## 一个简单的 Message

假设你有如下这个非常简单的 message 定义：

```sh
message Test1 {
  optional int32 a = 1;
}
```

在应用程序中，你创建了一个 `Test1` message 并将 `a` 设置为 150，然后将 message 序列化为输出流。如果你能够检查编码后的 message，则会看到三个字节：

```sh
08 96 01
```

这些数字的含义是什么呢？我们将稍后展示。

## Base 128 Varints

要理解 protocol buffer 的编码，首先需要了解 varints。varints 是一种将整数序列化成一个或多个字节的方法。数字越小使用的字节数也越小。

varint 中的每个字节（最后一个字节除外）都设置了最高有效位（most significant bit），简称 msb，表示还有后续字节，如果只有单个字节则不设置 msb。每个字节的低7位用于以7位一组的形式存储数字的二进制补码，**最低有效组放在前面**。

例如，数字1，它是一个单字节，所以 msb 没有被设置：

```sh
0000 0001
```
    
如果是300，就有点复杂：

    1010 1100 0000 0010
    
怎么知道这个是300的呢？首先从每个字节中删除 msb，因为 msb 只是告诉我们是否已达到数字的末尾。（如你所见，由于 varint 中有多个字节，所以 msb 被设置在第一个字节中）：


    1010 1100 0000 0010
    → 010 1100  000 0010


因为 varints 的最低有效组放在前面，所以需要反转两个7位组。最后进行拼接来获得实际的值：

```sh
000 0010  010 1100
→  000 0010 ++ 010 1100
→  100101100
→  256 + 32 + 8 + 4 = 300
```
    
## Message 结构

protocol buffer 的 message 是一系列 key-value 对。message 的二进制形式只使用了字段的编号作为 key，每个字段的名称和声明类型则是在解码端通过引用 message 类型的定义（即 `.proto` 文件）来确定的。

在对一个 message 进行编码时，key 和 value 被连接成一个字节流。当 message 被解码时，解析器需要跳过它无法识别的字段。这样，在 message 中添加新字段后也不会影响到旧程序。为此，每个 key 实际上由两个值组成：
1. `.proto` 文件中的字段编号。
2. 用来获取 value 长度信息的 wire 类型。

可用的 wire 类型如下：

|Type|Meaning|Used For|
|-|-|-|
|0|Varint|int32, int64, uint32, uint64, sint32, sint64, bool, enum|
|1|64-bit|fixed64, sfixed64, double|
|2|Length-delimited|string, bytes, embedded messages, packed repeated fields|
|3|Start group|groups (deprecated)|
|4|End group|groups (deprecated)|
|5|32-bit|fixed32, sfixed32, float|

在流式 message 中的每个 key 都是一个值为 `(field_number << 3) | wire_type` 的 varint。换句话说，数字的最后三位存储了 wire 类型。

现在让我们回过来看看之前那个简单的例子。你现在已经知道流中的第一个数字总是一个值为 varint 的 key，例子中 key 为 08（删除 msb）：

```sh
000 1000
```

取最后三位得到 wire 类型（0），然后右移三位得到字段编号（1）。所以字段编号是1，值是一个 varint。结合前面讲到的 varint 解码知识，可以看到接下来的两个字节存储的值为150。

```sh
96 01 = 1001 0110  0000 0001
       → 000 0001  ++  001 0110 (drop the msb and reverse the groups of 7 bits)
       → 10010110
       → 128 + 16 + 4 + 2 = 150
```

## 更多的 value 类型

#### 有符号整型（Signed Integers）

正如你在前面的章节中看到的那样，与 wire 类型0相关的所有 protocol buffer 类型都被编码为 varints。但是，在编码负数时，有符号的 int 类型（`sint32` 和 `sint64`）与“标准” int 类型（`int32` 和 `int64`）之间存在很大差异。如果使用 `int32` 或 `int64` 作为负数的类型，则生成的 varint 长度总是为10个字节 - 实际上，它被视为非常大的无符号整数；如果使用 `sint32` 或 `sint64`，对应的 varint 则会使用 ZigZag 编码，所以效率更高。

ZigZag 编码将有符号整数映射为无符号整数，因此绝对值小的数字（例如-1）就会有一个小的 varint 编码值。ZigZag 以一种在正整数和负整数之间来回“zig-zags”的方式来实现，所以-1被编码为1，1被编码为2，-2被编码为3，依此类推，如下表所示：

|Signed Original|Encoded As|
|-|-|
|0|0|
|-1|1|
|1|2|
|-2|3|
|2147483647|4294967294|
|-2147483648|4294967295|

换句话说，每个 `sint32` 类型的值 n 被编码为：

```sh
(n << 1) ^ (n >> 31)
```

每个 `sint64` 类型的值 n 被编码为：

```sh
(n << 1) ^ (n >> 63)
```

注意第二个移位操作 `n >> 31` 是一个算术移位。所以，这个移位操作的值要么所有位都是0（如果 n 是正数），要么所有位都为1（如果 n 是负数）。

在解析 `sint32` 或 `sint64` 时，其值按上述过程的逆操作解码回原来的有符号数。

#### 非 varint 数字（Non-varint Numbers）

非 varint 数字类型很简单，`double` 和 `fixed64` 的 wire 类型为1，它告诉解析器提取一块64位的数据；类似的， `float` 和 `fixed32` 的 wire 类型为5，它告诉解析器提取一块32位的数据。在这两种情况下，值都以小端字节顺序存储。

#### 字符串（Strings）

wire 类型 2 （length-delimited）表示该值是 varint 编码的长度，后面跟着指定的数据字节数。

例如有下面这样的 message 类型：

```sh
message Test2 {
  optional string b = 2;
}
```

将 b 的值设置为“testing”，会得到：

12 07 <span style="color:red">74 65 73 74 69 6e 67<span>

红色的字节部分是 UTF8 编码的“testing”。这里的 key 是 0x12，可以得到字段编号为2，wire 类型为2。07 表示 value 的长度为7，随后的7个字节就是我们的字符串。

#### 嵌套的 Message（Embedded Messages）

下面是一个带有我们示例类型 Test1 的嵌入式 message 的定义：

```sh
message Test3 {
  optional Test1 c = 3;
}
```

下面是编码后的结果，Test1 的字段 `a` 设置为150：

1a 03 <span style="color:red">08 96 01<span>

可以看到，最后三个字节与我们前面的第一个例子（`08 96 01`）完全相同，在它们前面是数字3。嵌入式 message 的处理方式与字符串完全相同（wire type = 2）。

#### 可选和重复的元素（Optional And Repeated Elements）

如果在 proto2 的 message 定义中有 `repeated` 的元素（没有`[packed = true]`选项），编码后的 message 会有零个或多个具有相同字段编号的 key-value 对。这些 repeated 的值不需要连续的出现，它们可能与其他的字段交错出现。解析时，这些元素相互之间的顺序会保存下来，但是相对于其他字段的顺序将会丢失。而 proto3 会利用打包编码（packed encoding）的方式对 repeated 字段进行编码，之后会介绍。

对于 proto3 中的任何非 `repeated` 字段或 proto2 中的 `optional` 字段，编码后的 message 可能有也可能没有该字段编号的 key-value 对。

通常，编码后的 message 永远不会有非 `repeated` 字段的多个实例。但是，解析器被设计为可以处理这种情况。对于数字类型和字符串，如果同一个字段出现多次，解析器将接受它看到的最后一个值。对于嵌套的 message 字段，解析器合并相同字段的多个实例，就像使用 `Message::MergeFrom` 方法一样 - 那就是，后面的实例的单个字段会替换掉前面出现的，单个嵌套 message 被合并，重复字段被连接起来。这些规则的效果是，解析串联出现的两个编码的 message 产生的结果和单独解析两个 message 然后合并它们的结果是相同的。示例如下：

```sh
MyMessage message;
message.ParseFromString(str1 + str2);
```

等同于：

```sh
MyMessage message, message2;
message.ParseFromString(str1);
message2.ParseFromString(str2);
message.MergeFrom(message2);
```

这个特性有的时候挺有用的，我们可以在不知道两个 message 的具体类型的情况下合并它们。


#### 打包重复字段（Packed Repeated Fields）

protocol buffer 在 2.1.0 版本引入了 packed repeated 字段，这个字段在 proto2 中的声明需要在 repeated 字段后面添加 `[packed=true]`。在 proto3 中，repeated 字段默认为 packed repeated 字段。这个字段和普通的 repeated 字段的区别在于编码方式不同。一个包含0个元素的 packed repeated 字段不会出现在编码后的 message 中。否则，该字段的所有元素都将打包到一个 wire 类型为2（length-delimited）的 key-value 对中。除了前面没有 key 以外，每个元素的编码方式与通常情况下相同。

假设你有如下的 message 类型：

```sh
message Test4 {
  repeated int32 d = 4 [packed=true];
}
```

现在构造一个 `Test4`，repeated 字段 `d` 的值有3、270和86942。编码后的结果如下：

```sh
22        // key (field number 4, wire type 2)
06        // payload size (6 bytes)
03        // first element (varint 3)
8E 02     // second element (varint 270)
9E A7 05  // third element (varint 86942)
```

只有原始数字类型（varint，32-bit 或 64-bit）的 repeated 字段才可以声明为“packed”。

请注意，虽然通常没有理由为 packed repeated 字段对多个 key-value 对进行编码，但编码器必须准备好接受多个 key-value 对。在这种情况下，payloads 应该被连接在一起。每一对都必须包含所有元素。

protocol buffer 解析器必须能够解析被编译为 packed 的 repeated 字段，就像它们未被打包一样，反之亦然。这就保证了 `[packed=true]` 选项的前后向兼容性。

#### 字段顺序（Field Order）

你可以在一个 .proto 文件中以任意顺序使用字段编号，当 message 被序列化时，已知的字段会按照字段编号顺序写入，可以参考提供的 C++，Java 和 Python 的序列化代码。这允许解析代码依赖于字段编号进行优化。但是，protocol buffer 解析器必须能够以任意顺序解析字段，因为并非所有 message 都是通过简单地序列化对象来创建的。例如，有时我们会通过一个简单的连接来合并两个 message。

如果 message 具有未知字段，则当前的 Java 和 C++ 实现在按顺序排序的已知字段之后以任意顺序写入它们，当前的 Python 实现则不会跟踪未知字段。
