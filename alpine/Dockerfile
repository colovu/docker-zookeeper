# Ver: 1.4 by Endial Fang (endial@126.com)
#

# 预处理 =========================================================================
ARG registry_url="registry.cn-shenzhen.aliyuncs.com"
FROM ${registry_url}/colovu/abuilder as builder

# sources.list 可使用版本：default / tencent / ustc / aliyun / huawei
ARG apt_source=aliyun

# 编译镜像时指定用于加速的本地服务器地址
ARG local_url=""

ENV APP_NAME=zookeeper \
	APP_VERSION=3.6.1

# 选择软件包源(Optional)，以加速后续软件包安装
RUN select_source ${apt_source};

# 安装依赖的软件包及库(Optional)
#RUN install_pkg xz-utils

# 下载并解压软件包 wait-for-port
RUN set -eux; \
	appName="wait-for-port-1.0.0-1-linux-amd64-debian-10.tar.gz"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/bitnami; \
	appUrls="${localURL:-} \
		https://downloads.bitnami.com/files/stacksmith \
		"; \
	download_pkg unpack ${appName} "${appUrls}"; \
	mv /usr/local/wait-for-port-1.0.0-1-linux-amd64-debian-10/files/common/bin/wait-for-port /usr/local/bin/; \
	chmod +x /usr/local/bin/wait-for-port;

# 下载并解压软件包 zookeeper
RUN set -eux; \
	appName="apache-${APP_NAME}-${APP_VERSION}-bin.tar.gz"; \
	appKeys="0x3D296268A36FACA1B7EAF110792D43153B5B5147 \
		0x52A7EA3EECAE05B0A8306471790761798F6E35FC \
		0xBBE7232D7991050B54C8EA0ADC08637CA615D22C \
		0x3F7A1D16FA4217B1DC75E1C9FFE35B7F15DFA1BA \
		0x586EFEF859AF2DB190D84080BDB2011E173C31A2 \
		"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/zookeeper; \
	appUrls="${localURL:-} \
		'https://www.apache.org/dyn/closer.cgi?action=download&filename='${APP_NAME}/${APP_NAME}-${APP_VERSION} \
		https://www-us.apache.org/dist/${APP_NAME}/${APP_NAME}-${APP_VERSION} \
		https://www.apache.org/dist/${APP_NAME}/${APP_NAME}-${APP_VERSION} \
		https://archive.apache.org/dist/${APP_NAME}/${APP_NAME}-${APP_VERSION} \
		"; \
	download_pkg unpack ${appName} "${appUrls}"; \
	rm -rf /usr/local/apache-${APP_NAME}-${APP_VERSION}-bin/docs;

# 镜像生成 ========================================================================
FROM ${registry_url}/colovu/openjre:8-alpine

# sources.list 可使用版本：default / tencent / ustc / aliyun / huawei
ARG apt_source=aliyun

# 编译镜像时指定用于加速的本地服务器地址
ARG local_url=""

# 镜像所包含应用的基础信息
ENV APP_NAME=zookeeper \
	APP_USER=zookeeper \
	APP_EXEC=zkServer.sh \
	APP_VERSION=3.6.1

ENV	APP_HOME_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME}

ENV PATH="${APP_HOME_DIR}/bin:${APP_HOME_DIR}/sbin:${PATH}" \
	LD_LIBRARY_PATH="${APP_HOME_DIR}/lib"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME}(v${APP_VERSION})." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

# 拷贝应用使用的客制化脚本，并创建对应的用户及数据存储目录
COPY customer /
RUN create_user && prepare_env

# 从预处理过程中拷贝软件包(Optional)，可以使用阶段编号或阶段命名定义来源
COPY --from=builder /usr/local/bin/ /usr/local/bin
COPY --from=builder /usr/local/apache-${APP_NAME}-${APP_VERSION}-bin/ /usr/local/${APP_NAME}
COPY --from=builder /usr/local/apache-${APP_NAME}-${APP_VERSION}-bin/conf/ /etc/${APP_NAME}

# 选择软件包源(Optional)，以加速后续软件包安装
RUN select_source ${apt_source}

# 安装依赖的软件包及库(Optional)
RUN install_pkg netcat-openbsd

# 执行预处理脚本，并验证安装的软件包
RUN set -eux; \
	override_file="/usr/local/overrides/overrides-${APP_VERSION}.sh"; \
	[ -e "${override_file}" ] && /bin/bash "${override_file}"; \
	gosu --version;

# 默认提供的数据卷
VOLUME ["/srv/conf", "/srv/data", "/srv/datalog", "/srv/cert", "/var/log"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 2181 2888 3888 8080

# 容器初始化命令，默认存放在：/usr/local/bin/entry.sh
ENTRYPOINT ["entry.sh"]

# 应用程序的服务命令，必须使用非守护进程方式运行。如果使用变量，则该变量必须在运行环境中存在（ENV可以获取）
CMD [ "${APP_EXEC}", "start-foreground" ]

