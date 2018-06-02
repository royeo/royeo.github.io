---
title: MySQL 性能优化
date: 2016-09-02 20:00:14
tags: MySQL
category: 码梦为生
---

MySQL性能优化的一些建议。

<!--more-->

## 复合索引

比如有一条语句是这样的：

```sql
select * from users where area = 'beijing' and age = 22;
```

如果我们是在 area 和 age 上分别创建单个索引的话，由于**MySQL查询每次只能使用一个索引**，所以虽然这样已经相对不做索引时全表扫描提高了很多效率，但是如果在 area、age 两列上创建复合索引的话将带来更高的效率。如果我们创建了 (area, age, salary) 的复合索引，那么其实相当于创建了 (area,age,salary)、(area,age)、(area) 三个索引，这被称为最佳左前缀特性。因此我们在创建复合索引时应该将最常用作限制条件的列放在最左边，依次递减。

<!--more-->

## 索引不会包含有NULL值的列

只要列中包含有 NULL 值都将不会被包含在索引中，复合索引中只要有一列含有 NULL 值，那么这一列对于此复合索引就是无效的。所以我们在数据库设计时不要让字段的默认值为 NULL 。

## like语句操作

一般情况下不鼓励使用 like 操作，如果非使用不可，如何使用也是一个问题。like “%aaa%” 不会使用索引，而 like “aaa%” 可以使用索引。

## 不要在列上进行运算

```sql
select * from users where YEAR(adddate) < 2007;
```

将在每个行上进行运算，这将导致索引失效而进行全表扫描，因此我们可以改成：

```sql
select * from users where adddate < ‘2007-01-01’;
```

## 不使用NOT IN和<>操作

NOT IN 和 <> 操作都不会使用索引将进行全表扫描。NOT IN 可以 NOT EXISTS 代替，id <> 3 则可使用 id > 3 or id < 3 来代替。

## 不建议使用float、double来存小数

为了防止精度丢失，建议使用 decimal 。

## 高效分页

limit m,n 其实是先执行 limit m + n，然后从第 m 行取 n 行，这样当 limit 翻页越往后越大，性能越低，如：

```sql
select * from users limit 100000, 10;
```

建议改成：

```sql
select * from users where id >= (select id from users limit 100000, 1) limit 10;
```

## 范围查找

范围查找包括 between、大于、小于以及 in 。mysql 中的 in 查询的条件有数量的限制，数量较小可以走索引，数量较大，就成了全表扫描了。而 between、大于、小于等，这些查询不会走索引，所以尽量放在走索引的查询条件后面。

## 多表链接

子查询和 join 都可以实现多张表之间取数据，但是子查询的性能较差，建议使用 join 。对于mysql的 join ，它用的是 Nested Loop Join 算法，也就是通过前一个表查询的结果集去后一个表中查询，比如前一个表的结果集是 100 条数据，后一个表有 10W 数据，就需要在 100 × 10W 的数据集合中取过滤的到最终的结果集，因此，尽量用小结果集的表去和大表做 join ，同时在 join 的字段上建立索引。
