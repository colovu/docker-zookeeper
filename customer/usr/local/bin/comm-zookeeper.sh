#!/bin/bash
# Ver: 1.1 by Endial Fang (endial@126.com)
# 
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/libcommon.sh       # 通用函数库

. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/libos.sh
. /usr/local/scripts/libservice.sh
. /usr/local/scripts/libvalidations.sh

# 函数列表

# 使用环境变量中以 "<PREFIX>" 开头的的全局变量更新指定配置文件中对应项（以"."分隔）
# 如果需要全部转换为小写，可使用命令： tr '[:upper:]' '[:lower:]'
# 全局变量:
#   <PREFIX>_* : 
#       替换规则（变量中字符  ==>  替换后全局变量中字符）：
#           - "." ==> "_"
#           - "_" ==> "__"
#           - "-" ==> "___"
#           
# 变量：
#   $1 - 配置文件
#   $2 - 前缀(不含结束的"_")
#   
# 举例：
#   CORE_CONF_fs_defaultFS 对应配置文件中的配置项：fs.defaultFS
zookeeper_configure_from_environment() {
    # Map environment variables to config properties
    for var in "${!APP_CFG_@}"; do
        key="$(echo "$var" | sed -e 's/^APP_CFG_//g' -e 's/_/\./g' | tr '[:upper:]' '[:lower:]')"
        value="${!var}"
        zookeeper_conf_set "$key" "$value"
    done

    local path="${1:?missing file}"
    local envPrefix="${2:?missing parameters}"

    LOG_D "  File: ${path}"
    # Map environment variables to config properties
    #for var in `printenv | grep ${envPrefix} | "${!${envPrefix}_@}"`; do
    #    LOG_D "  Process: ${var}"
    #    key="$(echo "${var}" | sed -e 's/^${envPrefix}_//g' -e 's/___/-/g' -e 's/__/_/g' -e 's/_/\./g')"
    #    value="${!var}"
    #    hadoop_common_xml_set "${path}"  "${key}" "${value}"
    #done
    #for var in $(printenv | grep ${envPrefix}); do
    #    LOG_D "  Process: ${var}"
    #    key="$(echo "${var}" | sed -e 's/^${envPrefix}_//g' -e 's/___/-/g' -e 's/__/_/g' -e 's/_/\./g' )"
    #    value="${!var}"
    #    hadoop_common_xml_set "${path}" "${key}" "${value}"
    #done
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=${envPrefix}`; do 
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/_/g; s/_/./g;'`
        key="${envPrefix}_${c}"
        #LOG_D "  Process: ${key} => ${!key}"
        value="${!key}"
        zookeeper_common_xml_set "${path}" "${name}" "${value}"
    done
}

# 将变量配置更新至配置文件
# 参数:
#   $1 - 文件
#   $2 - 变量
#   $3 - 值（列表）
zookeeper_common_conf_set() {
    local file="${1:?missing file}"
    local key="${2:?missing key}"
    shift
    shift
    local values=("$@")

    if [[ "${#values[@]}" -eq 0 ]]; then
        LOG_E "missing value"
        return 1
    elif [[ "${#values[@]}" -ne 1 ]]; then
        for i in "${!values[@]}"; do
            zookeeper_common_conf_set "$file" "${key[$i]}" "${values[$i]}"
        done
    else
        value="${values[0]}"
        # Check if the value was set before
        if grep -q "^[#\\s]*$key\s*=.*" "$file"; then
            # Update the existing key
            replace_in_file "$file" "^[#\\s]*${key}\s*=.*" "${key}=${value}" false
        else
            # 增加一个新的配置项；如果在其他位置有类似操作，需要注意换行
            printf "\n%s=%s" "$key" "$value" >>"$file"
        fi
    fi
}

# 更新 server.properties 配置文件中指定变量值
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
zookeeper_conf_set() {
    zookeeper_common_conf_set "${APP_CONF_DIR}/zoo.cfg" "$@"
}

# 更新 log4j.properties 配置文件中指定变量值
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
zookeeper_log4j_set() {
    zookeeper_common_conf_set "${APP_CONF_DIR}/log4j.properties" "$@"
}

# 使用环境变量中配置，更新配置文件
zookeeper_update_conf() {
    LOG_I "Update configure files..."

}

# 生成默认配置文件
zookeeper_generate_conf() {
    cp -rf "${APP_CONF_DIR}/zoo_sample.cfg" "${ZOO_CONF_FILE}"
    
    LOG_I "Modify config file via environment"
    echo "" >> "${ZOO_CONF_FILE}"

    zookeeper_conf_set "tickTime" "${ZOO_TICK_TIME}"
    zookeeper_conf_set "initLimit" "${ZOO_INIT_LIMIT}"
    zookeeper_conf_set "syncLimit" "${ZOO_SYNC_LIMIT}"
    zookeeper_conf_set "dataDir" "$APP_DATA_DIR"
    zookeeper_conf_set "dataLogDir" "${APP_DATA_LOG_DIR}"
    zookeeper_conf_set "clientPort" "$ZOO_PORT_NUMBER"
    zookeeper_conf_set "maxCnxns" "$ZOO_MAX_CNXNS"
    zookeeper_conf_set "maxClientCnxns" "$ZOO_MAX_CLIENT_CNXNS"
    zookeeper_conf_set "standaloneEnabled" "$ZOO_STANDALONE_ENABLED"
    zookeeper_conf_set "reconfigEnabled" "$(is_boolean_yes "$ZOO_RECONFIG_ENABLED" && echo true || echo false)"
    zookeeper_conf_set "quorumListenOnAllIPs" "$(is_boolean_yes "$ZOO_LISTEN_ALLIPS_ENABLED" && echo true || echo false)"
    zookeeper_conf_set "autopurge.purgeInterval" "$ZOO_AUTOPURGE_PURGEINTERVAL"
    zookeeper_conf_set "autopurge.snapRetainCount" "$ZOO_AUTOPURGE_SNAPRETAINCOUNT"
    zookeeper_conf_set "4lw.commands.whitelist" "$ZOO_4LW_COMMANDS_WHITELIST"

    if is_boolean_yes "${ZOO_ADMINSERVER_ENABLED}"; then
        zookeeper_conf_set "admin.enableServer" true
        zookeeper_conf_set "admin.serverAddress" "0.0.0.0"
        zookeeper_conf_set "admin.serverPort" 8080
        zookeeper_conf_set "admin.idleTimeout" 30000
        zookeeper_conf_set "admin.commandURL" "/commands"
    else
        zookeeper_conf_set "admin.enableServer" false
    fi

    # Set log level
    zookeeper_log4j_set "zookeeper.root.logger" "$ZOO_LOG4J_PROP"
    zookeeper_log4j_set "zookeeper.log.dir" "${APP_LOG_DIR}"

    # Add zookeeper servers to configuration    
    # key="$(echo "$var" | sed -e 's/^KAFKA_CFG_//g' -e 's/_/\./g' | tr '[:upper:]' '[:lower:]')"
    #read -r -a zookeeper_servers_list <<< "${ZOO_SERVERS//[;, ]/ }"
    #read -r -a zookeeper_servers_list <<< "$(tr '\"' '' <<< "${ZOO_SERVERS//[;, ]/ }")"
    #tmp_servers_list="$(echo ${ZOO_SERVERS//[;, ]/ } | sed -e 's/^\"//g' -e 's/\"$//g')" 
    read -r -a zookeeper_servers_list <<< "$(echo ${ZOO_SERVERS//[;, ]/ } | sed -e 's/^\"//g' -e 's/\"$//g')"
    if [[ ${#zookeeper_servers_list[@]} -gt 1 ]]; then
#        local i=1
        for server in "${zookeeper_servers_list[@]}"; do
            LOG_I "Adding server: ${server}"
            read -r -a server_info <<< "${server//=/ }"
            zookeeper_conf_set "${server_info[0]}" "${server_info[1]};${ZOO_PORT_NUMBER}"
#            (( i++ ))
        done
    else
        LOG_I "No additional servers were specified. ZooKeeper will run in standalone mode..."
    fi

    # If TLS in enable
    if is_boolean_yes "${ZOO_TLS_CLIENT_ENABLE}"; then
        zookeeper_conf_set "client.secure" true
        zookeeper_conf_set "secureClientPort" "$ZOO_TLS_PORT_NUMBER"
        zookeeper_conf_set "serverCnxnFactory" "org.apache.zookeeper.server.NettyServerCnxnFactory"
        zookeeper_conf_set "ssl.keyStore.location" "$ZOO_TLS_CLIENT_KEYSTORE_FILE"
        zookeeper_conf_set "ssl.keyStore.password" "$ZOO_TLS_CLIENT_KEYSTORE_PASSWORD"
        zookeeper_conf_set "ssl.trustStore.location" "$ZOO_TLS_CLIENT_TRUSTSTORE_FILE"
        zookeeper_conf_set "ssl.trustStore.password" "$ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD"
    fi
    if is_boolean_yes "${ZOO_TLS_QUORUM_ENABLE}"; then
        zookeeper_conf_set "sslQuorum" true
        zookeeper_conf_set "serverCnxnFactory" "org.apache.zookeeper.server.NettyServerCnxnFactory"
        zookeeper_conf_set "ssl.quorum.keyStore.location" "$ZOO_TLS_QUORUM_KEYSTORE_FILE"
        zookeeper_conf_set "ssl.quorum.keyStore.password" "$ZOO_TLS_QUORUM_KEYSTORE_PASSWORD"
        zookeeper_conf_set "ssl.quorum.trustStore.location" "$ZOO_TLS_QUORUM_TRUSTSTORE_FILE"
        zookeeper_conf_set "ssl.quorum.trustStore.password" "$ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD"
    fi
	
    echo "" >> "${ZOO_CONF_FILE}"

	zookeeper_update_conf
}

# 设置环境变量 JVMFLAGS
# 参数:
#   $1 - value
zookeeper_export_jvmflags() {
    local -r value="${1:?value is required}"

    export JVMFLAGS="${JVMFLAGS} ${value}"
    echo "export JVMFLAGS=\"${JVMFLAGS}\"" > "${APP_CONF_DIR}/java.env"
}

# 配置 HEAP 大小
# 参数:
#   $1 - HEAP 大小
zookeeper_configure_heap_size() {
    local -r heap_size="${1:?heap_size is required}"

    if [[ "${JVMFLAGS}" =~ -Xm[xs].*-Xm[xs] ]]; then
        LOG_D "Using specified values (JVMFLAGS=${JVMFLAGS})"
    else
        LOG_D "Setting '-Xmx${heap_size}m -Xms${heap_size}m' heap options..."
        zookeeper_export_jvmflags "-Xmx${heap_size}m -Xms${heap_size}m"
    fi
}

# 配置 ACL 参数
zookeeper_configure_acl() {
    local acl_string=""
    for server_user in ${ZOO_SERVER_USERS//[;, ]/ }; do
        acl_string="${acl_string},sasl:${server_user}:crdwa"
    done
    acl_string="${acl_string#,}"

    for path in / /zookeeper /zookeeper/quota; do
        LOG_I "Setting the ACL rule '${acl_string}' in ${path}"
        retry_while "zkCli.sh setAcl ${path} ${acl_string}" 80
    done
}

# 配置 zookeeper 启用认证
zookeeper_enable_authentication() {
    LOG_I "Enabling authentication..."
    zookeeper_conf_set "authProvider.1" "org.apache.zookeeper.server.auth.SASLAuthenticationProvider"
    zookeeper_conf_set "requireClientAuthScheme" sasl
}

# 为 zookeeper 认证创建 JAAS 配置文件
zookeeper_create_jaas_file() {
    LOG_I "Creating jaas file..."
    read -r -a server_users_list <<< "${ZOO_SERVER_USERS//[;, ]/ }"
    read -r -a server_passwords_list <<< "${ZOO_SERVER_PASSWORDS//[;, ]/ }"

    local zookeeper_server_user_passwords=""
    for i in $(seq 0 $(( ${#server_users_list[@]} - 1 ))); do
        zookeeper_server_user_passwords="${zookeeper_server_user_passwords}\n   user_${server_users_list[i]}=\"${server_passwords_list[i]}\""
    done
    zookeeper_server_user_passwords="${zookeeper_server_user_passwords#\\n   };"

    cat >"${APP_CONF_DIR}/zoo_jaas.conf" <<EOF
Client {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    username="$ZOO_CLIENT_USER"
    password="$ZOO_CLIENT_PASSWORD";
};
Server {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    $(echo -e -n "${zookeeper_server_user_passwords}")
};
EOF
    zookeeper_export_jvmflags "-Djava.security.auth.login.config=${APP_CONF_DIR}/zoo_jaas.conf"

    # Restrict file permissions
    _is_run_as_root && ensure_owned_by "${APP_CONF_DIR}/zoo_jaas.conf" "$APP_NAME"
    chmod 400 "${APP_CONF_DIR}/zoo_jaas.conf"
}

# Enable Prometheus metrics for ZooKeeper
zookeeper_enable_prometheus_metrics() {
    LOG_I "Enabling Prometheus metrics..."
    zookeeper_conf_set "metricsProvider.className" "org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider"
    zookeeper_conf_set "metricsProvider.httpPort" "${ZOO_PROMETHEUS_METRICS_PORT_NUMBER}"
    zookeeper_conf_set "metricsProvider.exportJvmInfo" true
}

# 检测用户参数信息是否满足条件; 针对部分权限过于开放情况，打印提示信息
zookeeper_verify_minimum_env() {
    local error_code=0

    LOG_D "Validating settings in ZOO_* env vars..."

    print_validation_error() {
        LOG_E "$1"
        error_code=1
    }

    # ZooKeeper authentication validations
    if is_boolean_yes "$ALLOW_ANONYMOUS_LOGIN"; then
        LOG_W "You have set the environment variable ALLOW_ANONYMOUS_LOGIN=${ALLOW_ANONYMOUS_LOGIN}. For safety reasons, do not use this flag in a production environment."
    elif ! is_boolean_yes "${ZOO_ENABLE_AUTH}"; then
        print_validation_error "The ZOO_ENABLE_AUTH environment variable does not configure authentication. Set the environment variable ALLOW_ANONYMOUS_LOGIN=yes to allow unauthenticated users to connect to ZooKeeper."
    fi

    # ZooKeeper port validations
    check_conflicting_ports() {
        local -r total="$#"

        for i in $(seq 1 "$((total - 1))"); do
            for j in $(seq "$((i + 1))" "$total"); do
                if (( "${!i}" == "${!j}" )); then
                    print_validation_error "${!i} and ${!j} are bound to the same port"
                fi
            done
        done
    }

    check_allowed_port() {
        local validate_port_args="-unprivileged"

        if ! err=$(validate_port "${validate_port_args[@]}" "${!1}"); then
            print_validation_error "An invalid port was specified in the environment variable $1: $err"
        fi
    }

    check_allowed_port ZOO_PORT_NUMBER
    check_allowed_port ZOO_PROMETHEUS_METRICS_PORT_NUMBER

    check_conflicting_ports ZOO_PORT_NUMBER ZOO_PROMETHEUS_METRICS_PORT_NUMBER

    # ZooKeeper server users validations
    read -r -a server_users_list <<< "${ZOO_SERVER_USERS//[;, ]/ }"
    read -r -a server_passwords_list <<< "${ZOO_SERVER_PASSWORDS//[;, ]/ }"
    if [[ ${#server_users_list[@]} -ne ${#server_passwords_list[@]} ]]; then
        print_validation_error "ZOO_SERVER_USERS and ZOO_SERVER_PASSWORDS lists should have the same length"
    fi

    # ZooKeeper server list validations
    if [[ -n $ZOO_SERVERS ]]; then
        read -r -a zookeeper_servers_list <<< "${ZOO_SERVERS//[;, ]/ }"
        for server in "${zookeeper_servers_list[@]}"; do
            if ! echo "$server" | grep -q -E "^[^:]+:[^:]+:[^:]+$"; then
                print_validation_error "Zookeeper server ${server} should follow the next syntax: host:port:port. Example: zookeeper:2888:3888"
            fi
        done
    fi

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

# 更改默认监听地址为 "*" 或 "0.0.0.0"，以对容器外提供服务；默认配置文件应当为仅监听 localhost(127.0.0.1)
zookeeper_enable_remote_connections() {
    LOG_D "Modify default config to enable all IP access"
	
}

# 检测依赖的服务端口是否就绪；该脚本依赖系统工具 'netcat'
# 参数:
#   $1 - host:port
zookeeper_wait_service() {
    local serviceport=${1:?Missing server info}
    local service=${serviceport%%:*}
    local port=${serviceport#*:}
    local retry_seconds=5
    local max_try=100
    let i=1

    if [[ -z "$(which nc)" ]]; then
        LOG_E "Nedd nc installed before, command: \"apt-get install netcat\"."
        exit 1
    fi

    LOG_I "[0/${max_try}] check for ${service}:${port}..."

    set +e
    nc -z ${service} ${port}
    result=$?

    until [ $result -eq 0 ]; do
      LOG_D "  [$i/${max_try}] not available yet"
      if (( $i == ${max_try} )); then
        LOG_E "${service}:${port} is still not available; giving up after ${max_try} tries."
        exit 1
      fi
      
      LOG_I "[$i/${max_try}] try in ${retry_seconds}s once again ..."
      let "i++"
      sleep ${retry_seconds}

      nc -z ${service} ${port}
      result=$?
    done

    set -e
    LOG_I "[$i/${max_try}] ${service}:${port} is available."
}

# 以后台方式启动应用服务，并等待启动就绪
zookeeper_start_server_bg() {
    zookeeper_is_server_running && return

    LOG_I "Starting ${APP_NAME} in background..."

	# 使用内置脚本启动服务
    local start_command="zkServer.sh start"
    if is_boolean_yes "${ENV_DEBUG}"; then
        $start_command &
    else
        $start_command >/dev/null 2>&1 &
    fi

    sleep 1
	# 通过命令或特定端口检测应用是否就绪
    LOG_I "Checking ${APP_NAME} ready status..."
    #wait-for-port --timeout 60 "$ZOO_PORT_NUMBER"
    zookeeper_wait_service "127.0.0.1:$ZOO_PORT_NUMBER"

    LOG_D "${APP_NAME} is ready for service..."
}

# 停止应用服务
zookeeper_stop_server() {
    #is_app_server_running || return
    LOG_I "Stopping ${APP_NAME}..."
    # 使用内置脚本关闭服务
    if [[ "$ENV_DEBUG" = true ]]; then
        "zkServer.sh" stop
    else
        "zkServer.sh" stop >/dev/null 2>&1
    fi
	
	# 检测停止是否完成
	local counter=10
    while [[ "$counter" -ne 0 ]] && zookeeper_is_server_running; do
        LOG_D "Waiting for ${APP_NAME} to stop..."
        sleep 1
        counter=$((counter - 1))
    done
}

# 检测应用服务是否在后台运行中
zookeeper_is_server_running() {
    LOG_D "Check if ${APP_NAME} is running..."
    local pid
    pid="$(get_pid_from_file '${ZOOPIDFILE}')"

    if [[ -z "${pid}" ]]; then
        false
    else
        is_service_running "${pid}"
    fi
}

# 清理初始化应用时生成的临时文件
zookeeper_clean_tmp_file() {
    LOG_D "Clean ${APP_NAME} tmp files for init..."

    # 需要删除初始化时生成的日志文件，否则应用启动会报错
    rm -rf ${APP_LOG_DIR}/*.out 
#    [[ ! -f "${APP_LOG_DIR}/zookeeper.out" ]] || mv "${APP_LOG_DIR}/zookeeper.out" "${APP_LOG_DIR}/zookeeper.out.firstboot"
}

# 在重新启动容器时，删除标志文件及必须删除的临时文件 (容器重新启动)
zookeeper_clean_from_restart() {
    LOG_D "Clean ${APP_NAME} tmp files for restart..."
    local -r -a files=(
        "${ZOOPIDFILE}"
    )

    for file in ${files[@]}; do
        if [[ -f "$file" ]]; then
            LOG_I "Cleaning stale $file file"
            rm "$file"
        fi
    done
}

# 应用默认初始化操作
# 执行完毕后，生成文件 ${APP_CONF_DIR}/.app_init_flag 及 ${APP_DATA_DIR}/.data_init_flag 文件
zookeeper_default_init() {
	zookeeper_clean_from_restart
    LOG_D "Check init status of ${APP_NAME}..."

    # 检测配置文件是否存在
    if [[ ! -f "${APP_CONF_DIR}/.app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
        zookeeper_generate_conf
        zookeeper_configure_heap_size "$HEAP_SIZE"
        if is_boolean_yes "${ZOO_ENABLE_AUTH}"; then
            zookeeper_enable_authentication
            zookeeper_create_jaas_file
        fi
        if is_boolean_yes "$ZOO_ENABLE_PROMETHEUS_METRICS"; then
            zookeeper_enable_prometheus_metrics
        fi

        touch "${APP_CONF_DIR}/.app_init_flag"
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> "${APP_CONF_DIR}/.app_init_flag"
    else
        LOG_I "User injected custom configuration detected!"

		LOG_D "Update configure files from environment..."
		zookeeper_update_conf
    fi

    if [[ ! -f "${APP_DATA_DIR}/.data_init_flag" ]]; then
        LOG_I "Deploying ${APP_NAME} from scratch..."
        echo "${ZOO_SERVER_ID}" > "${APP_DATA_DIR}/myid"

		# 检测服务是否运行中如果未运行，则启动后台服务
        #zookeeper_is_server_running || zookeeper_start_server_bg

        if is_boolean_yes "${ZOO_ENABLE_AUTH}" && [[ ${ZOO_SERVER_ID} -eq 1 ]] && [[ -n ${ZOO_SERVER_USERS} ]]; then
            zookeeper_configure_acl
        fi
		
        touch "${APP_DATA_DIR}/.data_init_flag"
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.data_init_flag
    else
        LOG_I "Deploying ${APP_NAME} with persisted data..."
    fi
}

# 用户自定义的前置初始化操作，依次执行目录 preinitdb.d 中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_preinit_flag
zookeeper_custom_preinit() {
    LOG_I "Check custom pre-init status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 preinitdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/preinitdb.d" ]; then
        # 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
        if [[ -n $(find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_preinit_flag" ]]; then
            LOG_I "Process custom pre-init scripts from /srv/conf/${APP_NAME}/preinitdb.d..."

            # 检索所有可执行脚本，排序后执行
            find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)" | sort | process_init_files

            touch "${APP_DATA_DIR}/.custom_preinit_flag"
            echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> "${APP_DATA_DIR}/.custom_preinit_flag"
            LOG_I "Custom preinit for ${APP_NAME} complete."
        else
            LOG_I "Custom preinit for ${APP_NAME} already done before, skipping initialization."
        fi
    fi

    # 检测依赖的服务是否就绪
    #for i in ${SERVICE_PRECONDITION[@]}; do
    #    zookeeper_wait_service "${i}"
    #done
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_init_flag
zookeeper_custom_init() {
    LOG_I "Check custom initdb status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 initdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
    	if [[ -n $(find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_init_flag" ]]; then
            LOG_I "Process custom init scripts from /srv/conf/${APP_NAME}/initdb.d..."

            # 检测服务是否运行中；如果未运行，则启动后台服务
            #zookeeper_is_server_running || zookeeper_start_server_bg

            # 检索所有可执行脚本，排序后执行
    		find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)" | sort | while read -r f; do
                case "$f" in
                    *.sh)
                        if [[ -x "$f" ]]; then
                            LOG_D "Executing $f"; "$f"
                        else
                            LOG_D "Sourcing $f"; . "$f"
                        fi
                        ;;
                    *.sql)    
                        LOG_D "Executing $f"; 
                        postgresql_execute "${PG_DATABASE}" "${PG_INITSCRIPTS_USERNAME}" "${PG_INITSCRIPTS_PASSWORD}" < "$f"
                        ;;
                    *.sql.gz) 
                        LOG_D "Executing $f"; 
                        gunzip -c "$f" | postgresql_execute "${PG_DATABASE}" "${PG_INITSCRIPTS_USERNAME}" "${PG_INITSCRIPTS_PASSWORD}"
                        ;;
                    *)        
                        LOG_D "Ignoring $f" ;;
                esac
            done

            touch "${APP_DATA_DIR}/.custom_init_flag"
    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> "${APP_DATA_DIR}/.custom_init_flag"
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi

    # 检测服务是否运行中；如果运行，则停止后台服务
	#zookeeper_is_server_running && zookeeper_stop_server

    # 删除第一次运行生成的临时文件
    zookeeper_clean_tmp_file

	# 绑定所有 IP ，启用远程访问
    zookeeper_enable_remote_connections
}

