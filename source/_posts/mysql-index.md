---
title: MySQL 索引的创建、删除和查看
date: 2016-11-15 22:04:35
tags: MySQL
category: 码梦为生
---

在索引列上，除了有序查找之外，数据库利用各种各样的快速定位技术，能够大大提高查询效率。特别是当数据量非常大，查询涉及多个表时，使用索引往往能使查询速度加快成千上万倍。

<!--more-->

 例如，有 3 个未索引的表 t1、t2、t3，分别只包含列 c1、c2、c3，每个表分别含有 1000 行数据组成，指为 1～1000 的数值，查找对应值相等行的查询如下所示。

```sql
SELECT c1, c2, c3 FROM t1, t2, t3 WHERE c1 = c2 AND c1 = c3
```

此查询结果应该为 1000 行，每行包含 3 个相等的值。在无索引的情况下处理此查询，必须寻找 3 个表所有的组合，以便得出与 WHERE 子句相配的那些行。而可能的组合数目为 1000 × 1000 × 1000（十亿），显然查询将会非常慢。

   如果对每个表进行索引，就能极大地加速查询进程。利用索引的查询处理如下。

（1）从表 t1 中选择第一行，查看此行所包含的数据。

（2）使用表 t2 上的索引，直接定位 t2 中与 t1 的值匹配的行。类似，利用表 t3 上的索引，直接定位 t3 中与来自 t1 的值匹配的行。

（3）扫描表 t1 的下一行并重复前面的过程，直到遍历 t1 中所有的行。

   在此情形下，仍然对表 t1 执行了一个完全扫描，但能够在表 t2 和 t3 上进行索引查找直接取出这些表中的行，比未用索引时要快一百万倍。

   利用索引，MySQL 加速了 WHERE 子句满足条件行的搜索，而在多表连接查询时，在执行连接时加快了与其他表中的行匹配的速度。

## 创建索引

在执行 CREATE TABLE 语句时可以创建索引，也可以单独用 CREATE INDEX 或 ALTER TABLE 来为表增加索引。

### ALTER TABLE

```sql
ALTER TABLE table_name ADD INDEX index_name (column_list)

ALTER TABLE table_name ADD UNIQUE (column_list)

ALTER TABLE table_name ADD PRIMARY KEY (column_list)
```
其中 table_name 是要增加索引的表名，column_list 指出对哪些列进行索引，多列时各列之间用逗号分隔。索引名 index_name 可选，缺省时，MySQL 将根据第一个索引列赋一个名称。另外，ALTER TABLE 允许在单个语句中更改多个表，因此可以在同时创建多个索引。

### CREATE INDEX

CREATE INDEX 可对表增加普通索引或 UNIQUE 索引。

 ```sql
CREATE INDEX index_name ON table_name (column_list)

CREATE UNIQUE INDEX index_name ON table_name (column_list)
```

table_name、index_name 和 column_list 具有与 ALTER TABLE 语句中相同的含义，索引名不可选。另外，不能用 CREATE INDEX 语句创建 PRIMARY KEY 索引。

### 索引类型

在创建索引时，可以规定索引能否包含重复值。如果不包含，则索引应该创建为 PRIMARY KEY 或 UNIQUE 索引。对于单列惟一性索引，这保证单列不包含重复的值。对于多列惟一性索引，保证多个值的组合不重复。

PRIMARY KEY 索引和 UNIQUE 索引非常类似。事实上，PRIMARY KEY 索引仅是一个具有名称 PRIMARY 的 UNIQUE 索引。这表示一个表只能包含一个 PRIMARY KEY，因为一个表中不可能具有两个同名的索引。

下面的SQL语句对 students 表在 sid 上添加 PRIMARY KEY 索引。

 ```sql
ALTER TABLE students ADD PRIMARY KEY (sid)
```

## 删除索引

可利用 ALTER TABLE 或 DROP INDEX 语句来删除索引。类似于 CREATE INDEX 语句，DROP INDEX 可以在 ALTER TABLE 内部作为一条语句处理，语法如下。

```sql
DROP INDEX index_name ON talbe_name

ALTER TABLE table_name DROP INDEX index_name

ALTER TABLE table_name DROP PRIMARY KEY
```

其中，前两条语句是等价的，删除掉 table_name 中的索引 index_name 。

第 3 条语句只在删除 PRIMARY KEY 索引时使用，因为一个表只可能有一个 PRIMARY KEY 索引，因此不需要指定索引名。如果没有创建 PRIMARY KEY 索引，但表具有一个或多个 UNIQUE 索引，则 MySQL 将删除第一个 UNIQUE 索引。

如果从表中删除了某列，则索引会受到影响。对于多列组合的索引，如果删除其中的某列，则该列也会从索引中删除。如果删除组成索引的所有列，则整个索引将被删除。

## 查看索引

```bash
mysql> show index from table_name;

mysql> show keys from table_name;
```

- Table

    表的名称。

- Non_unique

  如果索引不能包括重复词，则为 0 。如果可以，则为 1 。

- Key_name

  索引的名称。

- Seq_in_index

  索引中的列序列号，从 1 开始。

- Column_name

  列名称。

- Collation

  列以什么方式存储在索引中。在 MySQL 中，有值 A（升序）或 NULL（无分类）。

- Cardinality

  索引中唯一值的数目的估计值。通过运行 ANALYZE TABLE 或 myisamchk -a 可以更新。基数根据被存储为整数的统计数据来计数，所以即使对于小型表，该值也没有必要是精确的。基数越大，当进行联合时，MySQL 使用该索引的机会就越大。

- Sub_part

  如果列只是被部分地编入索引，则为被编入索引的字符的数目。如果整列被编入索引，则为 NULL 。

- Packed

  指示关键字如何被压缩。如果没有被压缩，则为 NULL 。

- Null

  如果列含有 NULL，则含有 YES 。如果没有，则该列含有 NO 。

- Index_type

  用过的索引方法（BTREE，FULLTEXT，HASH，RTREE）。

{% note class_name %} 本文转载自：[MySQL索引的创建、删除和查看](http://www.cnblogs.com/tianhuilove/archive/2011/09/05/2167795.html) {% endnote %}
