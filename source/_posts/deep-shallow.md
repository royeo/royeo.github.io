---
title: 如何编写一个 json 对象的拷贝函数
date: 2016-07-18 22:35:14
tags: JavaScript
category: 码梦为生
---

浅拷贝，比如浅拷贝对象A时，对象B将拷贝A的所有属性，如果属性是引用类型，B将拷贝地址，若果属性是基本类型，B将复制其值。浅拷贝的缺点是如果你修改了对象B中引用类型属性，你同时也会影响到对象A。

<!--more-->

深拷贝会完全拷贝所有数据，优点是拷贝双方不会相互依赖，比如修改了一方的引用类型属性，不会影响到另一方。缺点是拷贝的速度更慢，代价更大 （我的理解是耗费了更多内存空间）。

## 浅拷贝实现

1、使用 ES6 的 Object.assign，其内部实现就是浅拷贝，并剔除了目标对象的原型方法

```js
let a = {
  p: [1, 2]
};

let b = Object.assign({}, a);
console.log(b.p == a.p);
```
    
2、遍历对象属性

```js
function shallowClone(obj) {
  if (!obj || typeof obj !== 'object') {
    throw new Error('error arguments');
  }
  let targetObj = obj.constructor === Array ? [] : {};
  for (let key in obj) {
    if (obj.hasOwnProperty(key)) {
      targetObj[key] = obj[key];
    }
  }
  return targetObj;
}
```

## 深拷贝实现

1、利用 JSON 序列化实现一个深拷贝，缺点是无法复制函数，并且丢失抛弃对象的 constructor 和原型链

```js
function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

let o1 = {
  arr: [1, 2, 3],
  obj: { key: 'value' },
  func(){
    return 1;
  }
};
let o2 = deepClone(o1);
console.log(o2); // => {arr: [1,2,3], obj: {key: 'value'}}
```

2、利用递归实现深拷贝，可以复制函数，同样会丢失抛弃对象的 constructor 和原型链，但是对于拷贝 json 对象的话足够了

```js
function deepCopy(src) {
  if(!src || typeof src !== 'object'){
    throw new Error('error arguments');
  }
  let target = src.constructor === Array ? [] : {};
  for (let i in src) {
    if (typeof src[i] === 'object') {
      target[i] = src[i].constructor === Array ? [] : {};
      target[i] = deepCopy(src[i]);
    } else {
      target[i] = src[i];
    }
  }
  return target;
}
```

参考：[深入剖析 JavaScript 的深复制](http://jerryzou.com/posts/dive-into-deep-clone-in-javascript/)
