---
title: 基于二进制日志文件的 MySQL 复制实践
date: 2017-12-04 15:12:51
tags: 
  - MySQL
  - 主从复制
  - 码梦为生
---

本篇介绍基于二进制日志文件的 MySQL 复制，不谈原理，只讲实践。

1. 创建复制账号
2. 配置 master
3. 获取 master 二进制文件坐标
4. 配置 slave
5. 配置 slave 和 master 的通信
6. 开始复制

<!--more-->

## 1. 在 master 创建复制账号

每个 slave 都会使用 MySQL 用户名和密码连接到 master ，所以 master 上必须有一个用户帐户，并且被授予 `REPLICATION SLAVE` 权限。建议创建单独的复制账号。

```sh
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY 'replpass';
mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
```

## 2. 配置 master

master 需要开启二进制日志，以及指定一个独一无二的服务器 ID。在主库的 `my.cnf` 文件中增加或修改如下内容。修改完之后，需要重启 MySQL。

```cnf
[mysqld]
log-bin = mysql-bin
server-id = 10
```

- `log-bin`: 二进制文件的名称前缀。
- `server_id`: 复制组中的每个服务器都必须配置唯一的服务器标识。此 ID 用于标识组中的单个服务器，并且必须是 1 到 2^32 - 1 之间的正整数。一种通用的做法是使用服务器IP地址的末8位。

## 3. 获取 master 二进制文件坐标

为了配置 slave 在正确的位置启动复制过程，需要 master 的二进制日志中的当前坐标。

如果 master 没有数据，直接使用 `SHOW MASTER STATUS` 获取 master 的二进制文件名和位置（File & Position）。

如果 master 有数据，并且只包含InnoDB表，使用下面命令备份（前提是 master 配置好并重启）：

```sh
mysqldump -uroot -p123 -h127.0.0.1 -P3306 --single-transaction --master-data=2 --default-character-set=utf8mb4 --quick --triggers --hex-blob -B weibo_service > /root/weibo_service.sql
```

- 使用 `--master-data=2` 选项后，`CHANGE MASTER TO` 语句将写在备份文件开头的SQL注释中，如：

  ```sql
  -- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=313;
  ```

  在 slave 导入备份后，配置 slave 时，就可以直接使用上面的 master 二进制文件名和位置。

## 4. 配置 slave

如果 slave 的 server ID 尚未设置，或者当前值与 master 的值冲突，关闭 slave 并编辑配置文件的 [mysqld] 部分以指定一个唯一的 server ID，然后重启。

```config
[mysqld]
log_bin = mysql-bin
server_id = 2
relay-log = /var/lib/mysql/mysql-relay-bin
log-slave-updates = 1
read-only = 1
relicate-do-db = test
```

只有 `serve_id` 是必需的。其中一些选项只是显式地列出了默认值。

- `server-id`: 为了简便起见，我们将主库和备库上的log-bin设置为相同的值。如果省略server-id（或者将其明确设置为默认值0），则 slave 拒绝连接到 master。

- `log-bin`: 其实不需要在从站上启用二进制日志记录（log_bin）以进行复制设置，但是，如果在从站上启用二进制日志记录，则可以使用从站的二进制日志进行数据备份和崩溃恢复，还可以使用从站作为更复杂的复制拓扑的一部分。例如，这 slave 作为其他 slave 的 master。

- `relay-log`: 指定中继日志的位置和命名。通过设置relay_log可以避免中继日志文件基于机器名来命名。推荐设置。

- `log-slave-updates`: 允许备库将其重放的事件也记录到自身的二进制日志中。这会给备库增加额外的工作，但有时候只开启了二进制日志，却没有开启 log_slave_updates 可 能会碰到一些奇怪的现象。例如，当配置错误时可能会导致备库数据被修改。如果可能的话，最好使用 read_only 配置选项。

- `read-only`: 配置备库为只读。可以阻止大部分用户更改非临时表，除了复制SQL线程和其他拥有超级权限的用户之外，这也是要尽量避免给正常账号授予超级权限的原因之一。

- `relicate-do-db`: 指定主从复制的数据库

## 5. 配置 slave 和 master 通信进行复制

在 slave 上执行以下语句：

```sh
mysql> CHANGE MASTER TO
    ->     MASTER_HOST='master_host_name',              # master ip
    ->     MASTER_USER='replication_user_name',         # 复制账号
    ->     MASTER_PASSWORD='replication_password',      # 复制密码
    ->     MASTER_LOG_FILE='recorded_log_file_name',    # master 二进制日志文件名
    ->     MASTER_LOG_POS=recorded_log_position;        # master 二进制日志文件位置
```

## 6. 开始复制

在 slave 上执行以下语句：

```sh
mysql> START SLAVE;
```

再次检查复制是否正确执行：

```sh
mysql> SHOW SLAVE STATUS\G
******************************* 1. row **************************
      Slave一IO_State : Waiting for master to send event
          Master_Host : serverl
          Master_User : repl
            MasterPort: 3306
          ConnectRetry: 60
      Master_Log_File : mysql-bin.000001
  Read_Master_Log_Pos : 164
        Relay_Log_File: mysql-relay-bin.000001
        Relay_Log_Pos : 164
RelayJ1aster_Log_File : mysql-bin.000001
      Slave_IO_Running: Yes
    Slave_SQL_Running : Yes 
                    ......
Seconds_Behind_Master : 0
```
