#!/bin/bash
# docker entrypoint script

# 以下变量已在 Dockerfile 中定义，不需要修改
# APP_NAME: 应用名称，如 redis
# APP_EXEC: 应用可执行二进制文件，如 redis-server
# APP_USER: 应用对应的用户名，如 redis
# APP_GROUP: 应用对应的用户组名，如 redis

set -Eeo pipefail

LOG_RAW() {
	local type="$1"; shift
	printf '%s [%s] Entrypoint: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$type" "$*"
}
LOG_I() {
	LOG_RAW Note "$@"
}
LOG_W() {
	LOG_RAW Warn "$@" >&2
}
LOG_E() {
	LOG_RAW Error "$@" >&2
	exit 1
}

LOG_I "Initial container for ${APP_NAME}"

# 检测当前脚本是被直接执行的，还是从其他脚本中使用 "source" 调用的
_is_sourced() {
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}

# 使用root用户运行时，创建默认的数据目录，并拷贝所必须的默认配置文件及初始化文件
# 修改对应目录所属用户为应用对应的用户(Docker镜像创建时，相应目录默认为777模式)
docker_create_user_directories() {
	local user_id; user_id="$(id -u)"

	LOG_I "Check directories used by ${APP_NAME}"
	mkdir -p "${ZOO_LOG_DIR}"
	mkdir -p "${ZOO_DATA_DIR}"
	mkdir -p "${ZOO_DATA_LOG_DIR}"

	mkdir -p "${ZOO_CONF_DIR}"
	# 检测指定文件是否存在，如果不存在则拷贝
	[ ! -e ${ZOO_CONF_DIR}/configuration.xsl ] && cp /etc/${APP_NAME}/configuration.xsl ${ZOO_CONF_DIR}/configuration.xsl
	[ ! -e ${ZOO_CONF_DIR}/log4j.properties ] && cp /etc/${APP_NAME}/log4j.properties ${ZOO_CONF_DIR}/log4j.properties
	[ ! -e ${ZOO_CONF_DIR}/zoo_sample.cfg ] && cp /etc/${APP_NAME}/zoo_sample.cfg ${ZOO_CONF_DIR}/zoo_sample.cfg 

	# Generate the config only if it doesn't exist
	if [[ ! -f "$ZOO_CONF_DIR/zoo.cfg" ]]; then
		CONFIG="$ZOO_CONF_DIR/zoo.cfg"
		{
			echo "dataDir=$ZOO_DATA_DIR" 
			echo "dataLogDir=$ZOO_DATA_LOG_DIR"
			echo "clientPort=2181"

			echo "tickTime=$ZOO_TICK_TIME"
			echo "initLimit=$ZOO_INIT_LIMIT"
			echo "syncLimit=$ZOO_SYNC_LIMIT"

			echo "autopurge.snapRetainCount=$ZOO_AUTOPURGE_SNAPRETAINCOUNT"
			echo "autopurge.purgeInterval=$ZOO_AUTOPURGE_PURGEINTERVAL"
			echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS"
			echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED"
			echo "admin.enableServer=$ZOO_ADMINSERVER_ENABLED"
		} >> "$CONFIG"

		# ZOO_SERVERS主要用于集群配置，环境变量在启动容器时设置
		if [[ -z $ZOO_SERVERS ]]; then
			ZOO_SERVERS="server.1=localhost:2888:3888;2181"
		fi

		for server in $ZOO_SERVERS; do
			echo "$server" >> "$CONFIG"
		done

		if [[ -n $ZOO_4LW_COMMANDS_WHITELIST ]]; then
			echo "4lw.commands.whitelist=$ZOO_4LW_COMMANDS_WHITELIST" >> "$CONFIG"
		fi
	fi

	# 允许容器使用`--user`参数启动，修改相应目录的所属用户信息
	# 如果设置了'--user'，这里 user_id 不为 0
	# 如果没有设置'--user'，这里 user_id 为 0，需要使用默认用户名设置相关目录权限
	if [ "$user_id" = '0' ]; then
		find ${ZOO_LOG_DIR} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		find ${ZOO_CONF_DIR} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		find ${ZOO_DATA_DIR} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		find ${ZOO_DATA_LOG_DIR} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		# 修改目录读写属性，使用`:`命令是为了保证不会因部分目录权限问题，导致命令失败而使得容器退出
		chmod 755 ${ZOO_LOG_DIR} ${ZOO_CONF_DIR} ${ZOO_DATA_DIR} ${ZOO_DATA_LOG_DIR} || :
		# 解决使用gosu后，nginx: [emerg] open() "/dev/stdout" failed (13: Permission denied)
		chmod 0622 /dev/stdout /dev/stderr
	fi

	# 在文件不存在时，写入myid
	# ZOO_SERVER_ID 主要用于集群配置，环境变量在启动容器时设置
	if [[ ! -f "$ZOO_DATA_DIR/myid" ]]; then
		echo "${ZOO_SERVER_ID:-1}" > "$ZOO_DATA_DIR/myid"
	fi
}

# 检测可能导致容器执行后直接退出的命令，如"--help"；如果存在，直接返回 0
docker_app_want_help() {
	local arg
	for arg; do
		case "$arg" in
			-'?'|--help|-V|--version)
				return 0
				;;
		esac
	done
	return 1
}

_main() {
	# 如果命令行参数是以配置参数("-")开始，修改执行命令，确保使用可执行应用命令启动服务器
	if [ "${1:0:1}" = '-' ]; then
		set -- ${APP_EXEC} "$@"
	fi

	# 命令行参数以可执行应用命令起始，且不包含直接返回的命令(如：-V、--version、--help)时，执行初始化操作
	if [ "$1" = "${APP_EXEC}" ] && ! docker_app_want_help "$@"; then
		# 创建并设置数据存储目录与权限
		docker_create_user_directories

		# 以root用户运行时，使用gosu重新以"postgres"用户运行当前脚本
		if [ "$(id -u)" = '0' ]; then
			LOG_I "Restart container with default user: ${APP_USER}'"
			LOG_I ""
			exec gosu ${APP_USER} "$0" "$@"
		fi
	fi

	LOG_I "Start container with: $@"
	# 执行命令行
	exec "$@"
}

if ! _is_sourced; then
	_main "$@"
fi
