# ZooKeeper

针对 [ZooKeeper](https://zookeeper.apache.org/) 应用的 Docker 镜像，用于提供 ZooKeeper 服务。

详细信息可参照：[3.5.7官方说明](https://zookeeper.apache.org/doc/r3.5.7/index.html)



![logo](img/zookeeper-logo.png)

**版本信息**：

- 3.5

**镜像信息**

* 镜像地址：
  - Aliyun仓库：registry.cn-shenzhen.aliyuncs.com/colovu/zookeeper:3.5
  - DockerHub：colovu/zookeeper:3.5
  * 依赖镜像：colovu/openjre:8

> 后续相关命令行默认使用`[Docker Hub](https://hub.docker.com)`镜像服务器做说明



## TL;DR

Docker 快速启动命令：

```shell
$ docker run -d -e ALLOW_ANONYMOUS_LOGIN=yes colovu/zookeeper:3.5
```




Docker-Compose 快速启动命令：

```shell
# 从 Gitee 下载 Compose 文件
$ curl -sSL -o https://gitee.com/colovu/docker-zookeeper/raw/3.5/docker-compose.yml

# 从 Github 下载 Compose 文件
$ curl -sSL -o https://raw.githubusercontent.com/colovu/docker-zookeeper/3.5/docker-compose.yml

# 创建并启动容器
$ docker-compose up -d
```



---



## 默认对外声明

### 端口

- 2181：Zookeeper 业务客户端访问端口
- 2888：Follower port （跟随者通讯端口）
- 3888：Election port （选举通讯端口）
- 8080：AdminServer port （管理界面端口）

### 数据卷

镜像默认提供以下数据卷定义，默认数据分别存储在自动生成的应用名对应`zookeeper`子目录中：

```shell
/var/log                # 日志输出，应用日志输出，非数据日志输出；自动创建子目录zookeeper
/srv/conf               # 配置文件；自动创建子目录zookeeper
/srv/data               # 数据文件；自动创建子目录zookeeper
/srv/datalog            # 数据操作日志文件；自动创建子目录zookeeper
```

如果需要持久化存储相应数据，需要**在宿主机建立本地目录**，并在使用镜像初始化容器时进行映射。宿主机相关的目录中如果不存在对应应用 Zookeeper 的子目录或相应数据文件，则容器会在初始化时创建相应目录及文件。



## 容器配置

在初始化 ZooKeeper 容器时，如果配置文件`zoo.cfg`不存在，可以在命令行中设置相应环境变量对默认参数进行修改。类似命令如下：

```shell
$ docker run -d -e "ZOO_INIT_LIMIT=10" --name zookeeper colovu/zookeeper:3.5
```



### 常规配置参数

常使用的环境变量主要包括：
- **ALLOW_ANONYMOUS_LOGIN**：默认值：**no**。设置是否允许匿名连接。如果没有设置`ZOO_ENABLE_AUTH`，则必须设置当前环境变量为 `yes`
- **ZOO_LISTEN_ALLIPS_ENABLED**：默认值：**no**。设置是否默认监听所有 IP
- **ZOO_TICK_TIME**：默认值：**2000**。设置`tickTime`。定义一个 Tick 的时间长度，以微秒为单位。该值为 ZooKeeper 使用的基础单位，用于心跳、超时等控制；如一般 Session 的最小超时时间为2个 Ticks
- **ZOO_INIT_LIMIT**：默认值：**10**。设置 `initLimit`。以 ticks 为单位的时间长度。用于控制从服务器与 Leader 连接及同步的时间。如果数据量比较大，可以适当增大该值
- **ZOO_SYNC_LIMIT**：默认值：**5**。设置`syncLimit`。以 ticks 为单位的时间长度。用于控制从服务器同步数据的时间。如果从服务器与 Leader 差距过大，将会被剔除
- **ZOO_MAX_CLIENT_CNXNS**：默认值：**60**。设置`maxClientCnxns`。每个客户端允许的同时连接数（Socket层）。以 IP 地址来识别客户端
- **ZOO_STANDALONE_ENABLED**：默认值：**false**。设置使用启用 Standalone 模式。参考[`standaloneEnabled`](https://zookeeper.apache.org/doc/r3.5.5/zookeeperReconfig.html#sc_reconfig_standaloneEnabled)中的定义。

> 3.5.0版本新增。配置服务器工作模式，支持 Standalone 和 Distributed 两种。在服务器启动后无法重新切换。服务器启动时，默认会设置为 true，服务器将无法动态扩展。为了后续服务器可动态扩展，可设置该值为 false。

- **ZOO_ADMINSERVER_ENABLED**：默认值：**true**。 设置是否启用管理服务器。参考[`admin.enableServer`](http://zookeeper.apache.org/doc/r3.5.5/zookeeperAdmin.html#sc_adminserver_config)中定义。

> 3.5.0版本新增。 配置是否启用 AdminServer，该服务是一个内置的 Jetty 服务器，可以提供 HTTP 访问端口以支持四字命令。默认情况下，该服务工作在 8080 端口，访问方式为： URL "/commands/[command name]", 例如, http://localhost:8080/commands/stat。

- **ZOO_AUTOPURGE_PURGEINTERVAL**：默认值：**0**。设置自动清理触发周期，参考 [`autoPurge.purgeInterval`](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_advancedConfiguration)中的定义。以小时为单位自动清理触发时间。设置为正整数（1 或更大值）以启用服务器自动清理快照及日志功能。设置为 0 则不启用。
- **ZOO_AUTOPURGE_SNAPRETAINCOUNT**：默认值：**3**。设置自动清理范围，参考[`autoPurge.snapRetainCount`](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_advancedConfiguration)中的定义。当自动清理功能启用时，保留的最新快照或日志数量；其他的快照及保存在 dataDir、dataLogDir 中的数据将被清除。最小值为 3。

- **ZOO_4LW_COMMANDS_WHITELIST**：默认值：**srvr, mntr**。设置白名单，参考 [`4lw.commands.whitelist`](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_clusterOptions)中的定义。以逗号分隔的四字命令。需要将有效的四字命令使用该环境变量进行设置；如果不设置，则对应的四字命令默认不起作用。



### 可选配置参数

如果没有必要，可选配置参数可以不用定义，直接使用对应的默认值，主要包括：

- **ENV_DEBUG**：默认值：**false**。设置是否输出容器调试信息。可设置为：1、true、yes
- **ZOO_PORT_NUMBER**：默认值：**2181**。设置应用的默认客户访问端口
- **ZOO_MAX_CNXNS**：默认值：**0**。设置当前服务器最大连接数。设置为 0 则无限制
- **ZOO_LOG4J_PROP**：默认值：**INFO,CONSOLE**。设置日志输出级别及输出方式；开启多种输出方式时，会影响应用程序性能。日志级别取值范围：`ALL`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `OFF`, `TRACE`。输出方式取值可为多个，以`,`分隔，取值范围：`CONSOLE`、`ROLLINGFILE`、`TRACEFILE`
- **ZOO_RECONFIG_ENABLED**：默认值：**no**。设置是否启用动态重新配置功能
- **ZOO_ENABLE_PROMETHEUS_METRICS**：默认值：**no**。设置是否输出 Prometheus 指标
- **ZOO_PROMETHEUS_METRICS_PORT_NUMBER**：默认值：**7000**。设置 Jetty 默认输出 Prometheus 指标的端口
- **ZOO_ENABLE_AUTH**：默认值：**no**。设置是否启用认证。使用  SASL/Digest-MD5 加密
- **ZOO_CLIENT_USER**：默认值：**无**。客户端认证的用户名
- **ZOO_CLIENT_PASSWORD**：默认值：**无**。客户端认证的用户密码
- **ZOO_CLIENT_PASSWORD_FILE**：默认值：**无**。以绝对地址指定的客户端认证用户密码存储文件。该路径指的是容器内的路径
- **ZOO_SERVER_USERS**：默认值：**无**。服务端创建的用户列表。多个用户使用逗号、分号、空格分隔
- **ZOO_SERVER_PASSWORDS**：默认值：**无**。服务端创建的用户对应的密码。多个用户密码使用逗号、分号、空格分隔。例如：pass4user1, pass4user2, pass4admin
- **ZOO_SERVER_PASSWORDS_FILE**：默认值：**无**。以绝对地址指定的服务器用户密码存储文件。多个用户密码使用逗号、分号、空格分隔。例如：pass4user1, pass4user2, pass4admin。该路径指的是容器内的路径
- **JVMFLAGS**：默认值：**无**。设置服务默认的 JVMFLAGS
- **HEAP_SIZE**：默认值：**1024**。设置以 MB 为单位的 Java Heap 参数（Xmx 与 Xms）。如果在 JVMFLAGS 中已经设置了 Xmx 与 Xms，则当前设置会被忽略



### 集群配置参数

使用 ZooKeeper 镜像，可以很容易的建立一个 [ZooKeeper](https://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html) 集群。针对 ZooKeeper 的集群模式，有以下参数可以配置：

#### `ZOO_SERVER_ID`

默认值：**1**

介于1~255之间的唯一值，用于标识服务器ID。需要注意，如果在初始化容器时使用一个存在`myid`文件的宿主机路径映射为容器的`/srv/data`数据卷，则相应的`ZOO_SERVER_ID`参数设置不起作用。容器中文件完整路径为：`/srv/data/zookeeper/myid`。

#### `ZOO_SERVERS`

默认值：**server.1=0.0.0.0:2888:3888**

定义集群模式时的服务器列表。每个服务器使用类似`server.id=host:port:port`的格式进行定义，如：`server.2=192.168.0.1:2888:3888`。不同的服务器参数使用空格或逗号分隔。需要注意，如果在初始化容器时使用一个存在`zoo.cfg`文件的本地路径映射为`/srv/conf`数据卷，则相应的参数设置不起作用。文件完整路径为：`/srv/conf/zookeeper/zoo.conf`。此时如果需要更新配置，只能手动修改配置文件，并重新启动容器。

常用格式为 `server.X=A:B:C`，参考信息如下:

- `server.`: 关键字，不可以更改
- X: 数字，当前服务器的ID，在同一个集群中应当唯一
- A: IP地址或主机名（网络中可识别）
- B: 当前服务器与集群中 Leader 交换消息所使用的端口
- C: 选举 Leader 时所使用的端口

更多信息，可参照文档 [Zookeeper Dynamic Reconfiguration](https://zookeeper.apache.org/doc/r3.5.5/zookeeperReconfig.html) 中的介绍。



### TLS配置参数

使用证书加密传输时，相关配置参数如下：

- **ZOO_TLS_CLIENT_ENABLE**：启用或禁用 TLS。默认值：**no**
- **ZOO_TLS_PORT_NUMBER**：使用 TLS 加密传输的端口。默认值：**3181**
- **ZOO_TLS_CLIENT_KEYSTORE_FILE**：
- **ZOO_TLS_CLIENT_KEYSTORE_PASSWORD**：
- **ZOO_TLS_CLIENT_TRUSTSTORE_FILE**：
- **ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD**：

- **ZOO_TLS_QUORUM_ENABLE**：启用或禁用Quorum的 TLS。默认值：**no**
- **ZOO_TLS_QUORUM_KEYSTORE_FILE**：
- **ZOO_TLS_QUORUM_KEYSTORE_PASSWORD**：
- **ZOO_TLS_QUORUM_TRUSTSTORE_FILE**：
- **ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD**：



## 安全

### 用户及密码

Zookeeper 镜像默认禁用了无密码访问功能，在实际生产环境中建议使用用户名及密码控制访问；如果为了测试需要，可以使用以下环境变量启用无密码访问功能：

```shell
ALLOW_ANONYMOUS_LOGIN=yes
```



通过配置环境变量`ZOO_ENABLE_AUTH`，可以启用基于 SASL/Digest-MD5 加密的用户认证功能。在启用用户认证时，同时需要设置相应用户名及密码。

> 启用认证后，用户使用 CLI 工具`zkCli.sh`时，也需要进行认证，可通过`. /usr/local/bin/entrypoint.sh`来使用环境变量中的默认密码。

命令行使用参考：

```shell
$ docker run -d -e ZOO_ENABLE_AUTH=yes \
	-e ZOO_SERVER_USERS=user1,user2 \
	-e ZOO_SERVER_PASSWORDS=pass4user1,pass4user2 \
	-e ZOO_CLIENT_USER=user1 \
	-e ZOO_CLIENT_PASSWORD=pass4user1 \
	colovu/zookeeper:3.5
```

使用 Docker Compose 时，`docker-compose.yml`应包含类似如下配置：

```yaml
services:
  zookeeper:
  ...
    environment:
      - ZOO_ENABLE_AUTH=yes
      - ZOO_SERVER_USERS=user1,user2
      - ZOO_SERVER_PASSWORDS=pass4user1,pass4user2
      - ZOO_CLIENT_USER=user1
      - ZOO_CLIENT_PASSWORD=pass4user1
  ...
```

### 容器安全

本容器默认使用`non-root`运行应用，以加强容器的安全性。在使用`non-root`用户运行容器时，相关的资源访问会受限；应用仅能操作镜像创建时指定的路径及数据。使用`non-root`方式的容器，更适合在生产环境中使用。



如果需要切换为`root`方式运行应用，可以在启动命令中增加`-u root`以指定运行的用户。



## 注意事项

- 容器中应用的启动参数不能配置为后台运行，如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



## 更新记录

- 3.5



----

本文原始来源 [Endial Fang](https://github.com/colovu) @ [Github.com](https://github.com)

