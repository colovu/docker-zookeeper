# ZooKeeper

针对 ZooKeeper 应用的 Docker 镜像，用于提供 ZooKeeper 服务。

![logo](img/logo.png)

**版本信息**：

- 3.5.7、latest

**镜像信息**

* 镜像地址：endial/zookeeper:latest
  * 依赖镜像：endial/openjdk:8u242-jre



## 默认对外声明

### 端口

- 2181：Client port
- 2888：Follower port
- 3888：Election port
- 8080：AdminServer port

### 数据卷

镜像默认提供以下数据卷定义：

```shell
/var/log			# 日志输出，应用日志输出，非数据日志输出
/srv/conf			# 配置文件
/srv/data			# 数据文件
/srv/datalog	# 数据操作日志文件
```

如果需要持久化存储相应数据，需要在宿主机建立本地目录，并在使用镜像初始化容器时进行数据卷映射。

举例：

- 使用宿主机`/host/dir/to/conf`存储配置文件
- 使用宿主机`/host/dir/to/data`存储数据文件
- 使用宿主机`/host/dir/to/log`存储日志文件

创建以上相应的宿主机目录后，容器启动命令中对应的数据卷映射参数类似如下：

```shell
-v /host/dir/to/conf:/srv/conf -v /host/dir/to/data:/srv/data -v /host/dir/to/log:/var/log
```

> 注意：应用需要使用的子目录会自动创建。



## 使用说明

- 在后续介绍中，启动的容器默认命名为`zk-name`，需要根据实际情况修改



### 实例化ZooKeeper服务容器

#### 单机版容器初始化

直接运行一个默认容器：

```shell
$ docker run -d --restart always --name zk-name endial/zookeeper:latest
```

使用数据卷映射生成并运行一个容器：

```shell
 $ docker run -d --restart always \
  --name zk-name \
  -v /host/dir/to/data:/srv/data \
  -v /host/dir/to/datalog:/srv/datalog \
  -v /host/dir/to/conf:/srv/conf \
  endial/zookeeper:latest
```



#### 集群版容器初始化

可以使用 [`docker stack deploy`](https://docs.docker.com/engine/reference/commandline/stack_deploy/) 或 [`docker-compose`](https://github.com/docker/compose) 方式，启动一组服务容器。使用 `stack.yml` 配置文件方式参考如下：

```yaml
version: '3.1'

services:
  zoo1:
    image: endial/zookeeper:latest
    restart: always
    hostname: zoo1
    ports:
      - 2181:2181
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=0.0.0.0:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181

  zoo2:
    image: endial/zookeeper:latest
    restart: always
    hostname: zoo2
    ports:
      - 2182:2181
    environment:
      ZOO_MY_ID: 2
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=0.0.0.0:2888:3888;2181 server.3=zoo3:2888:3888;2181

  zoo3:
    image: endial/zookeeper:latest
    restart: always
    hostname: zoo3
    ports:
      - 2183:2181
    environment:
      ZOO_MY_ID: 3
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=0.0.0.0:2888:3888;2181
```

以上方式将以 [replicated mode](https://zookeeper.apache.org/doc/current/zookeeperStarted.html#sc_RunningReplicatedZooKeeper) 启动ZooKeeper 3.5。也可以以  [Docker Swarm](https://www.docker.com/products/docker-swarm) 方式进行配置。

> 注意：在一个机器上设置多个服务容器，并不能提供冗余特性；如果主机因各种原因导致宕机，则所有 ZooKeeper 服务都会下线。如果需要完全的冗余特性，需要在完全独立的不同物理主机中启动服务容器；即使在一个集群的中的不同虚拟主机中启动单独的服务容器也无法完全避免因物理主机宕机导致的问题。



#### 使用数据卷容器简化命令

如果存在 dvc（endial/dvc-alpine） 数据卷容器：

```shell
$ docker run -d --restart always \
  --name zk-name \
  --volumes-from dvc \
  endial/zookeeper:latest
```



### 连接容器

其他业务容器连接至 ZooKeeper 容器：

```shell
$ docker run --name other-app --link zk-name:zookeeper -d other-app-image:tag
```

使用命令行初始化并连接至 ZooKeeper 容器：

```shell
$ docker run -it --rm --link zk-name:zookeeper endial/zookeeper:latest zkCli.sh -server zookeeper
```



使用容器ID或启动时的命名（本例中命名为`php-fpm`）进入容器：

```shell
$ docker exec -it zk-name /bin/bash
```

使用 attach 命令进入已运行的容器：

```shell
$ docker attach zk-name
```





### 停止容器

使用容器ID或启动时的命名（本例中命名为`php-fpm`）停止：

```shell
$ docker stop zk-name
```

使用 ZooKeeper 容器中`zkServer.sh`管理脚本的停止命令停止容器：

```shell
$ docker exec -it zk-name zkServer.sh stop
```



### 查看日志

默认方式启动容器时（没有挂载`/srv/log`数据卷），应用的日志输出至终端，可使用如下方式进行查看：

```shell
$ docker logs zk-name
```

在使用 Docker Compose 管理容器时，使用以下命令查看：

```shell
$ docker-compose logs zoo1
```





## 容器配置

Zookeeper 容器的配置文件默认存储在数据卷`/srv/conf`中，文件名及子路径为`zookeeper/zoo.cfg`。有以下两种方式可以使用自定义的配置文件：

- 直接映射配置文件

```shell
$ docker run -d --restart always --name zk-name -v $(pwd)/zoo.cfg:/srv/conf/zookeeper/zoo.cfg endial/zookeeper:latest
```

- 映射配置文件数据卷

```shell
$ docker run -d --restart always --name zk-name -v $(pwd):/srv/conf endial/zookeeper:latest
```

> 第二种方式时，本地路径中需要包含zookeeper子目录，且相应文件存放在该目录中



## 环境变量

在初始化 ZooKeeper 容器时，如果配置文件`zoo.cfg`不存在，可以在命令行中使用相应参数对默认参数进行修改。类似命令如下：

```shell
$ docker run -d --restart always -e "ZOO_INIT_LIMIT=10" --name zk-name endial/zookeeper:latest
```



### `ZOO_TICK_TIME`

Defaults to `2000`. ZooKeeper's `tickTime`

> The length of a single tick, which is the basic time unit used by ZooKeeper, as measured in milliseconds. It is used to regulate heartbeats, and timeouts. For example, the minimum session timeout will be two ticks

### `ZOO_INIT_LIMIT`

Defaults to `5`. ZooKeeper's `initLimit`

> Amount of time, in ticks (see tickTime), to allow followers to connect and sync to a leader. Increased this value as needed, if the amount of data managed by ZooKeeper is large.

### `ZOO_SYNC_LIMIT`

Defaults to `2`. ZooKeeper's `syncLimit`

> Amount of time, in ticks (see tickTime), to allow followers to sync with ZooKeeper. If followers fall too far behind a leader, they will be dropped.

### `ZOO_MAX_CLIENT_CNXNS`

Defaults to `60`. ZooKeeper's `maxClientCnxns`

> Limits the number of concurrent connections (at the socket level) that a single client, identified by IP address, may make to a single member of the ZooKeeper ensemble.

### `ZOO_STANDALONE_ENABLED`

Defaults to `true`. Zookeeper's [`standaloneEnabled`](https://zookeeper.apache.org/doc/r3.5.5/zookeeperReconfig.html#sc_reconfig_standaloneEnabled)

> Prior to 3.5.0, one could run ZooKeeper in Standalone mode or in a Distributed mode. These are separate implementation stacks, and switching between them during run time is not possible. By default (for backward compatibility) standaloneEnabled is set to true. The consequence of using this default is that if started with a single server the ensemble will not be allowed to grow, and if started with more than one server it will not be allowed to shrink to contain fewer than two participants.

### `ZOO_ADMINSERVER_ENABLED`

Defaults to `true`. Zookeeper's [`admin.enableServer`](http://zookeeper.apache.org/doc/r3.5.5/zookeeperAdmin.html#sc_adminserver_config)

> New in 3.5.0: The AdminServer is an embedded Jetty server that provides an HTTP interface to the four letter word commands. By default, the server is started on port 8080, and commands are issued by going to the URL "/commands/[command name]", e.g., http://localhost:8080/commands/stat.

### `ZOO_AUTOPURGE_PURGEINTERVAL`

Defaults to `0`. Zookeeper's [`autoPurge.purgeInterval`](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_advancedConfiguration)

> The time interval in hours for which the purge task has to be triggered. Set to a positive integer (1 and above) to enable the auto purging. Defaults to 0.

### `ZOO_AUTOPURGE_SNAPRETAINCOUNT`

Defaults to `3`. Zookeeper's [`autoPurge.snapRetainCount`](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_advancedConfiguration)

> When enabled, ZooKeeper auto purge feature retains the autopurge.snapRetainCount most recent snapshots and the corresponding transaction logs in the dataDir and dataLogDir respectively and deletes the rest. Defaults to 3. Minimum value is 3.

### `ZOO_4LW_COMMANDS_WHITELIST`

Defaults to `srvr`. Zookeeper's [`4lw.commands.whitelist`](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_clusterOptions)

> A list of comma separated Four Letter Words commands that user wants to use. A valid Four Letter Words command must be put in this list else ZooKeeper server will not enable the command. By default the whitelist only contains "srvr" command which zkServer.sh uses. The rest of four letter word commands are disabled by default.



## 冗余模式配置参数

针对 ZooKeeper 的冗余模式（复制模式），有以下参数可以配置。

### `ZOO_MY_ID`

介于1~255之间的唯一值，用于标识服务器ID。需要注意，如果在初始化容器时使用一个存在`myid`文件的本地路径映射为`/srv/data`数据卷，则相应的参数设置不起作用。文件完整路径为：`/srv/data/zookeeper/myid`。

### `ZOO_SERVERS`

定义冗余模式时的服务器列表。每个服务器使用类似`server.id=::[:role];[:]`的格式进行定义，如：`serverid.2=2888:3888;2181`。不同的服务器参数使用空格分隔。需要注意，如果在初始化容器时使用一个存在`zoo.cfg`文件的本地路径映射为`/srv/conf`数据卷，则相应的参数设置不起作用。文件完整路径为：`/srv/conf/zookeeper/zoo.conf`。此时如果需要更新配置，只能手动修改配置文件，并重新启动容器。

更多信息，可参照文档 [Zookeeper Dynamic Reconfiguration](https://zookeeper.apache.org/doc/r3.5.5/zookeeperReconfig.html) 中的介绍。



## 配置持久化数据存储

ZooKeeper 镜像默认配置了用于存储数据及数据日志的数据卷 `/srv/data`和`/srv/datalog`。可以使用宿主机目录映射相应的数据卷，将数据持久化存储在宿主机中。

> 注意：将数据持久化存储至宿主机，可避免容器销毁导致的数据丢失。同时，将数据存储及数据日志分别映射为不同的本地设备（如不同的共享数据存储）可提供较好的性能保证。



## 配置日志输出

默认情况下，ZooKeeper 容器将 stdout/stderr 信息重定向至终端进行输出。可以配置将相应信息输出至`/srv/log`数据卷的相应文件中。配置方式使用 `ZOO_LOG4J_PROP` 类似如下在容器实例化时进行配置：

```shell
$ docker run -d --restart always --name zk-name -e ZOO_LOG4J_PROP="INFO,ROLLINGFILE" endial/zookeeper:latest
```

使用该配置后，相应的系统日志文件，将会存储在数据卷`/var/log`的 `zookeeper/zookeeper.log`文件中。

更多有关日志的使用帮助，可参考文档 [ZooKeeper Logging](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_logging) 中更多说明。



## 升级容器

如果容器镜像版本有更新，在运行的业务系统可根据需要升级至相应版本的镜像。

1. 下载新版本的容器（下载最新版本或指定的tag）

   ```shell
   $ docker pull endial/zookeeper/latest
   ```

2. 停止当前容器并备份数据

   ```shell
   $ docker stop zk-name
   ```

   或使用 Docker Compose 时：

   ```shell
   $ docker-compose down zoo1
   ```

   

3. 删除当前容器

   ```shell
   $ docker rm -v zk-name
   ```

   或使用 Docker Compose时：

   ```shell
   $ docker-compose rm -v zoo1
   ```

   

4. 使用新的镜像启动新的容器

   使用之前容器的启动命令启动容器（映射数据卷）：

   ```shell
   $ dockzk-name -d --restart always --name zk-name endial/zookeeper/latest
   ```

   或使用 Docker Compose时：

   ```shell
   $ docker-compose up zoo1
   ```

   

----

本文原始来源 [Endial Fang](https://github.com/endial) @ [Github.com](https://github.com)
