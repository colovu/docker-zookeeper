FROM colovu/openjdk:11.0.7-jre

ARG zookeeper_ver=3.5.7

ENV APP_NAME=zookeeper \
	APP_EXEC=zkServer.sh \
	APP_USER=zookeeper \
	APP_GROUP=zookeeper \
	APP_VERSION=${zookeeper_ver}

ENV	APP_DEF_DIR=/etc/${APP_NAME} \
	APP_CONF_DIR=/srv/conf/${APP_NAME} \
	APP_DATA_DIR=/srv/data/${APP_NAME} \
	APP_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
	APP_CACHE_DIR=/var/cache/${APP_NAME} \
	APP_RUN_DIR=/var/run/${APP_NAME} \
	APP_LOG_DIR=/var/log/${APP_NAME} \
	APP_CERT_DIR=/srv/cert/${APP_NAME} \
	APP_WWW_DIR=/srv/www \
	\
	ZOO_CONF_DIR=/srv/conf/${APP_NAME} \
	ZOO_DATA_DIR=/srv/data/${APP_NAME} \
	ZOO_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
	ZOO_LOG_DIR=/var/log/${APP_NAME} \
	\
	ZOOCFGDIR=/srv/conf/${APP_NAME} \
	ZOOPIDFILE=/var/run/${APP_NAME}/zookeeper_server.pid \
	PATH=/usr/local/${APP_NAME}/bin:${PATH}

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME} ${APP_VERSION}." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

COPY prebuilds /

RUN set -eux; \
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
# 设置入口脚本的可执行权限
	chmod +x /usr/local/bin/entrypoint.sh; \
	\
# 为应用创建对应的组、用户、相关目录
	APP_DIRS="${APP_DEF_DIR:-} ${APP_CONF_DIR:-} ${APP_DATA_DIR:-} ${APP_CACHE_DIR:-} ${APP_RUN_DIR:-} ${APP_LOG_DIR:-} ${APP_CERT_DIR:-} ${APP_WWW_DIR:-} ${APP_DATA_LOG_DIR:-}"; \
	groupadd -r ${APP_GROUP}; \
	useradd -r -g ${APP_GROUP} -s /usr/sbin/nologin ${APP_USER}; \
	mkdir -p ${APP_DIRS}; \
	\
# 安装临时使用的软件包，在使用完后会进行删除
	fetchDeps=" \
		wget \
		ca-certificates \
		\
		dirmngr \
		gnupg \
		\
		netcat \
#		gzip \
#		libc6 \
#		procps \
#		tar \
#		zlib1g \
		"; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ${fetchDeps}; \
	\
# 使用下载(编译)方式安装软件
	DIST_NAME="wait-for-port-1.0.0-1-linux-amd64-debian-10"; \
	DIST_URL=" \
#		http://192.168.1.187/dist-files/ \
		https://downloads.bitnami.com/files/stacksmith/ \
		"; \
	. /usr/local/scripts/libdownload.sh && download_dist "${DIST_NAME}.tar.gz" "${DIST_URL}"; \
	\
# 二进制解压
	APP_BIN="/usr/local/bin"; \
	tar --extract --gunzip --file "${DIST_NAME}.tar.gz" --directory "${APP_BIN}" --strip-components 4 "${DIST_NAME}/files/common/bin/"; \
	rm -rf "${DIST_NAME}.tar.gz" "/usr/local/bin/.buildcomplete"; \
	\
	\
	DIST_NAME="apache-${APP_NAME}-${APP_VERSION}-bin.tar.gz"; \
	DIST_KEYID="0x3D296268A36FACA1B7EAF110792D43153B5B5147"; \
	DIST_URL=" \
		'https://www.apache.org/dyn/closer.cgi?action=download&filename='${APP_NAME}/${APP_NAME}-${APP_VERSION}/ \
		https://www-us.apache.org/dist/${APP_NAME}/${APP_NAME}-${APP_VERSION}/ \
		https://www.apache.org/dist/${APP_NAME}/${APP_NAME}-${APP_VERSION}/ \
		https://archive.apache.org/dist/${APP_NAME}/${APP_NAME}-${APP_VERSION}/ \
		"; \
	. /usr/local/scripts/libdownload.sh && download_dist "${DIST_NAME}" "${DIST_URL}" --pgpkey "${DIST_KEYID}"; \
	\
# 二进制解压
	APP_BIN="/usr/local/${APP_NAME}"; \
	mkdir -p ${APP_BIN}; \
	tar --extract --gunzip --file "${DIST_NAME}" --directory "${APP_BIN}" --strip-components 1; \
	cp -rf ${APP_BIN}/conf/* "${APP_DEF_DIR}/"; \
	rm -rf "${DIST_NAME}"; \
	\
# 检测是否存在overrides脚本文件，如果存在，执行
	{ [ ! -e "/usr/local/overrides/overrides-${APP_VERSION}.sh" ] || /bin/bash "/usr/local/overrides/overrides-${APP_VERSION}.sh"; }; \
	\
# 设置临时目录的权限信息，设置为777是为了保证后续使用`--user`或`gosu`时，可以更改目录对应的用户属性信息；运行时会被更改为700或755
	chown -Rf ${APP_USER}:${APP_GROUP} ${APP_DIRS}; \
	chmod 777 ${APP_DIRS}; \
	\
# 查找新安装的应用及应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
	apt-mark auto '.*' > /dev/null; \
	{ [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; }; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual; \
	\
# 删除安装的临时依赖软件包，清理缓存
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${fetchDeps}; \
	apt-get autoclean -y; \
	rm -rf /var/lib/apt/lists/*; \
	\
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	: ;


VOLUME ["/srv/conf", "/srv/data", "/srv/datalog", "/var/log"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 2181 2888 3888 8080

# 容器初始化命令，默认存放在：/usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# 应用程序的服务命令，必须使用非守护进程方式运行
CMD [ "zkServer.sh", "start-foreground" ]
