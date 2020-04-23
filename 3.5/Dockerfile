FROM endial/openjdk:8u242-jre

ARG zookeeper_ver=3.5.7

ENV APP_NAME=zookeeper \
	APP_EXEC=zkServer.sh \
	APP_USER=zookeeper \
	APP_GROUP=zookeeper \
	GPG_KEY='3D296268A36FACA1B7EAF110792D43153B5B5147' \
	SHORT_DISTRO_NAME=zookeeper-${zookeeper_ver} \
	DISTRO_NAME=apache-zookeeper-${zookeeper_ver}-bin

ENV	ZOO_CONF_DIR=/srv/conf/${APP_NAME} \
    ZOO_DATA_DIR=/srv/data/${APP_NAME} \
    ZOO_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
    ZOO_LOG_DIR=/var/log/${APP_NAME} \
    \
    ZOO_TICK_TIME=2000 \
    ZOO_INIT_LIMIT=5 \
    ZOO_SYNC_LIMIT=2 \
    ZOO_AUTOPURGE_PURGEINTERVAL=0 \
    ZOO_AUTOPURGE_SNAPRETAINCOUNT=3 \
    ZOO_MAX_CLIENT_CNXNS=60 \
    ZOO_STANDALONE_ENABLED=true \
    ZOO_ADMINSERVER_ENABLED=true \
    \
    PATH=$PATH:/usr/local/${APP_NAME}/bin \
    ZOOCFGDIR=/srv/conf/${APP_NAME} \
    ZOOPIDFILE=/var/run/${APP_NAME}/zookeeper_server.pid

LABEL \
	"Version"="v${zookeeper_ver}" \
	"Description"="Docker image for ${APP_NAME} ${zookeeper_ver} based on Ubuntu 18.04." \
	"Dockerfile"="https://github.com/endial/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

RUN set -eux; \
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
	groupadd -r ${APP_GROUP}; \
	useradd -r -g ${APP_GROUP} -s /usr/sbin/nologin -d /usr/cache/${APP_NAME} ${APP_USER}; \
	\
	mkdir -p /usr/local/${APP_NAME} ${ZOO_CONF_DIR} ${ZOO_LOG_DIR} /var/run/${APP_NAME} ${ZOO_DATA_DIR} ${ZOO_DATA_LOG_DIR}; \
	\
# 更新源，并安装临时使用的软件包（使用完后可删除）
	fetchDeps=" \
		netcat \
# 签名验证工具
		dirmngr \
		gnupg \
# 下载工具
		ca-certificates \
		wget \
	"; \
	apt update; \
	apt install -y --no-install-recommends ${fetchDeps}; \
	\
	ddist() { \
		local f="$1"; shift; \
		local distFile="$1"; shift; \
		local success=; \
		local distUrl=; \
		for distUrl in \
			'https://www.apache.org/dyn/closer.cgi?action=download&filename=' \
			https://www-us.apache.org/dist/ \
			https://www.apache.org/dist/ \
			https://archive.apache.org/dist/ \
		; do \
			if wget -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
				success=1; \
				break; \
			fi; \
		done; \
		[ -n "$success" ]; \
	}; \
	ddist "$DISTRO_NAME.tar.gz" "zookeeper/$SHORT_DISTRO_NAME/$DISTRO_NAME.tar.gz"; \
	ddist "$DISTRO_NAME.tar.gz.asc" "zookeeper/$SHORT_DISTRO_NAME/$DISTRO_NAME.tar.gz.asc"; \
	\
# 安装软件包需要使用的GPG证书
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "${GPG_KEY}" || \
	gpg --batch --keyserver pgp.mit.edu --recv-keys "${GPG_KEY}" || \
	gpg --batch --keyserver keys.gnupg.net --recv-keys "${GPG_KEY}" || \
	gpg --batch --keyserver keyserver.pgp.com --recv-keys "${GPG_KEY}"; \
	gpg --batch --export "${GPG_KEY}" > /etc/apt/trusted.gpg.d/${APP_NAME}.gpg; \
	gpg --batch --verify "$DISTRO_NAME.tar.gz.asc" "$DISTRO_NAME.tar.gz"; \
	command -v gpgconf > /dev/null && gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	apt-key list; \
	\
	tar -zxf "$DISTRO_NAME.tar.gz" --strip-components=1 -C "/usr/local/${APP_NAME}"; \
	ln -sf "/usr/local/${APP_NAME}/conf" "/etc/${APP_NAME}"; \
	rm -rf "$DISTRO_NAME.tar.gz" "$DISTRO_NAME.tar.gz.asc"; \
	\
# 设置临时目录的权限信息，设置为777是为了保证后续使用`--user`或`gosu`时，可以更改目录对应的用户属性信息
	chown -Rf ${APP_USER}:${APP_GROUP} ${ZOO_CONF_DIR} ${ZOO_LOG_DIR} /var/run/${APP_NAME} ${ZOO_DATA_DIR} ${ZOO_DATA_LOG_DIR}; \
# this 777 will be replaced by 700 or 755 at runtime (allows semi-arbitrary "--user" values)
	chmod 777 ${ZOO_CONF_DIR} ${ZOO_LOG_DIR} /var/run/${APP_NAME} ${ZOO_DATA_DIR} ${ZOO_DATA_LOG_DIR}; \
	\
# 删除临时软件包，清理缓存
	apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${fetchDeps}; \
	apt autoclean -y; \
	rm -rf /var/lib/apt/lists/*;


COPY ./entrypoint.sh /usr/local/bin/

VOLUME ["/srv/conf", "/srv/data", "/srv/datalog", "/var/log"]

# 如果使用gosu启动，必须保证端口在1024之上
EXPOSE 2181 2888 3888 8080

WORKDIR $DISTRO_NAME

ENTRYPOINT ["entrypoint.sh"]

CMD [ "zkServer.sh", "start-foreground" ]
