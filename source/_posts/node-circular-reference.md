---
title: Node 循环依赖之源码解析
date: 2018-01-29 21:59:08
tags:
  - Node
  - 模块
  - 源码
  - 循环依赖
category: 码梦为生
---

今天来讲一讲 Node 循环依赖的问题，以官网上的例子结合 Node 源码来分析为什么循环依赖不会导致死循环，以及循环依赖可能造成的问题。

<!--more-->

## 案例

官网上给出的例子是这样的：

`a.js`:

```js
console.log('a starting');
exports.done = false;
const b = require('./b.js');
console.log('in a, b.done = %j', b.done);
exports.done = true;
console.log('a done');
```

`b.js`:

```js
console.log('b starting');
exports.done = false;
const a = require('./a.js');
console.log('in b, a.done = %j', a.done);
exports.done = true;
console.log('b done');
```

`main.js`:

```js
console.log('main starting');
const a = require('./a.js');
const b = require('./b.js');
console.log('in main, a.done=%j, b.done=%j', a.done, b.done);
```

官网的解释是： `main.js` 先加载 `a.js`，然后 `a.js` 中会加载 `b.js`，但是在 `b.js` 中又加载了 `a.js`。这个时候为了防止无限循环，会将`a.js` 未完成的 `exports` 对象返回给 `b.js` 模块，接着 `b.js` 完成加载，并且它的 `exports` 对象被提供给 `a.js` 模块。

由此可以看出，之所以不会发生依赖的死循环，是因为模块能够导出未完成的 `exports` 对象。那么问题来了，为什么模块没有执行完，却能导出对象呢？

下面通过分析模块源码 [lib/module.js](https://github.com/nodejs/node/blob/master/lib/module.js) 来解答这个问题。要注意的是，核心模块和文件模块（用户编写的模块）的加载是不同的，本文只讨论文件模块的加载。为了便于理解，会对源码进行简化。

## Module 构造函数

在 Node 中，每个模块在被 `require` 导入的时候都会创建一个模块实例，即 `Module` 实例，并且 Node 会缓存每个模块的实例，以便在下次 `require` 该模块的时候可以直接从缓存中返回。

模块实例有一个 `exports` 属性，初始化为空对象。当我们在文件模块中通过 `module.exports` 或 `exports` 来导出的时候，其实就是在给模块实例的 `exports` 添加属性或者直接重写它。

```js
// Module 构造函数
function Module(id, parent) {
  this.id = id;
  this.exports = {};
  this.parent = parent;
  updateChildren(parent, this, false);
  this.filename = null;
  this.loaded = false;
  this.children = [];
}
```

## require 方法

`require` 方法定义在 `Module` 的原型链上，被每个模块实例共享。

```js
Module.prototype.require = function(id) {
  return Module._load(id, this, false);
};
```

`require` 内部调用 `Module._load` 方法，下面是简化后的 `_load` 方法。

```js
Module._load = function(request, parent, isMain) {
  // 获取模块文件的绝对路径
  var filename = Module._resolveFilename(request, parent, isMain);

  // 如果有缓存，直接返回缓存中的模块实例的 exports 属性
  var cachedModule = Module._cache[filename];
  if (cachedModule) {
    return cachedModule.exports;
  }

  // 如果是核心模块，使用 NativeModule.require 方法加载
  if (NativeModule.nonInternalExists(filename)) {
    return NativeModule.require(filename);
  }

  // 创建模块实例，并存入缓存
  var module = new Module(filename, parent);
  Module._cache[filename] = module;

  // 加载模块
  module.load(filename);

  return module.exports;
};
```

上面的代码中，以模块的绝对路径作为模块id，优先从缓存中获取模块实例的 `exports` 属性。如果模块实例不在缓存中，则创建模块实例并存入缓存，最后根据模块id调用 `module.load` 加载该模块。

## 加载模块

模块的加载通过 `module.load` 方法完成，该方法根据模块的绝对路径确定文件扩展名，不同的文件扩展名采用不同的加载方法。

```js
Module.prototype.load = function(filename) {
  this.filename = filename;
  this.paths = Module._nodeModulePaths(path.dirname(filename));

  var extension = path.extname(filename) || '.js';
  if (!Module._extensions[extension]) extension = '.js';
  Module._extensions[extension](this, filename);
  this.loaded = true;
};
```

以 `.js` 扩展名为例，处理方法如下：

```js
Module._extensions['.js'] = function(module, filename) {
  var content = fs.readFileSync(filename, 'utf8');
  module._compile(internalModule.stripBOM(content), filename);
};
```

`module._compile` 方法对模块文件进行编译执行。

```js
Module.prototype._compile = function(content, filename) {
  // 将模块代码包装在一个函数中
  var wrapper = Module.wrap(content);

  // 在当前全局上下文中编译包装好的模块代码，并返回一个可执行的函数
  var compiledWrapper = vm.runInThisContext(wrapper, { ... });

  // 获取模块目录的路径
  var dirname = path.dirname(filename);

  // 扩展 require 方法，如添加 require.resolve、require.cache 等属性
  var require = internalModule.makeRequireFunction(this);

  // 传入模块实例的 exports 属性、require 方法、模块实例自身、完整文件路径
  // 和文件目录来执行该函数。
  var result = compiledWrapper.call(this.exports, this.exports, require, this,
                                  filename, dirname);
  return result;
};
```

```js
Module.wrap = function(script) {
  return Module.wrapper[0] + script + Module.wrapper[1];
};

Module.wrapper = [
  '(function (exports, require, module, __filename, __dirname) { ',
  '\n});'
];
```

`vm.runInThisContext` 这个方法会在 V8 虚拟机环境中编译代码，并在当前全局的上下文中运行代码并返回结果。在全局上下文运行的好处是在模块中我们可以使用一些全局变量，如：`process`、`console` 等。具体参考：[vm 的官方文档](https://nodejs.org/dist/latest-v8.x/docs/api/vm.html)。

上面的代码使用 `Module.wrap` 将模块代码包装在函数中，这样就避免了作用域被污染，接着通过执行 `vm.runInThisContext` 返回一个可执行的函数，最后传入当前模块实例的 `exports` 属性、模块实例的 `this`，以及`require` 方法、完整文件路径和文件目录来执行该函数。

由此也可以看出，`module.exports` 和 `exports` 并不是全局的，而是在执行模块代码的包装函数时传入的参数（当前模块实例的 `exports`）。这也解释了为什么在文件模块中重写 `exports` 会无法导出，因为它只能改变函数形参的引用，而无法实际影响到当前模块实例的 `exports` 属性。

## 循环依赖

在分析完模块的整个加载过程后，回到上面那个问题：为什么模块没有执行完，却能导出对象呢？关键就在于，在加载模块时，如果模块没有缓存，会先创建模块实例，然后存入缓存，再编译执行模块代码。

以官网的例子来说：

1. `a.js` 先加载，所以先缓存 `a.js` 的模块实例，然后编译执行 `a.js`。

2. 在执行 `a.js` 的过程中，先导出 `exports.done = false`，此时 `a.js` 模块实例的 `exports` 属性值为 `{ done: false }`。接着加载 `b.js`。

3. `b.js` 在执行过程中发现需要加载 `a.js`，此时由于 `a.js` 模块已经被缓存，所以直接获取到缓存中的 `a.js` 模块实例的 `exports` 属性，值为 `{ done: false }`，然后继续执行。

4. `b.js` 执行完毕返回，`a.js` 继续执行。

这种循环依赖导致的问题很明显：

1. `b.js` 在执行过程中获取到的 `a.js` 的导出可能是不完整的。

2. 如果 `a.js` 在加载 `b.js` 后重写了 `module.exports`，`b.js` 中获取到的 `a.js` 的导出还是维持着旧的引用。

具体的解决方案可以参考 Maples7 的博客：[Node.js 中的模块循环依赖及其解决](http://maples7.com/2016/08/17/cyclic-dependencies-in-node-and-its-solution/)。

## References

- [Modules | Node.js Documentation](https://nodejs.org/docs/latest-v8.x/api/modules.html)
- [VM | Node.js Documentation](https://nodejs.org/docs/latest-v8.x/api/vm.html)
- [node/lib/module.js - Github](https://github.com/nodejs/node/blob/master/lib/module.js)
- [require() 源码解读 - 阮一峰](http://www.ruanyifeng.com/blog/2015/05/require.html)
- [Node.js 中的循环依赖 - SegmentFault](https://segmentfault.com/a/1190000004151411)
- [Node.js 中的模块循环依赖及其解决 - Maples7](http://maples7.com/2016/08/17/cyclic-dependencies-in-node-and-its-solution/)
