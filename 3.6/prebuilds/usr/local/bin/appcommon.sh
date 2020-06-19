#!/bin/bash
#
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/liblog.sh
. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/libcommon.sh
. /usr/local/scripts/libvalidations.sh

# 函数列表

# 加载应用使用的环境变量初始值，该函数在相关脚本中以eval方式调用
# 全局变量:
#   ENV_* : 容器使用的全局变量
#   ZOO_* : 应用配置文件使用的全局变量，变量名根据配置项定义
# 返回值:
#   可以被 'eval' 使用的序列化输出
docker_app_env() {
    # 以下变量已经在创建镜像时定义，可直接使用
    # APP_NAME、APP_EXEC、APP_USER、APP_GROUP、APP_VERSION
    # APP_BASE_DIR、APP_DEF_DIR、APP_CONF_DIR、APP_CERT_DIR、APP_DATA_DIR、APP_CACHE_DIR、APP_RUN_DIR、APP_LOG_DIR
    cat <<"EOF"
# Debug log message
export ENV_DEBUG=${ENV_DEBUG:-false}

# Paths
export ZOO_BASE_DIR="/usr/local/${APP_NAME}"
export ZOO_DATA_DIR="${APP_DATA_DIR}"
export ZOO_DATA_LOG_DIR="${APP_DATA_LOG_DIR}"
export ZOO_CONF_DIR="${APP_CONF_DIR}"
export ZOO_CONF_FILE="${ZOO_CONF_DIR}/zoo.cfg"
export ZOO_LOG_DIR="${APP_LOG_DIR}"
#export ZOO_BIN_DIR="${ZOO_BASE_DIR}/bin"

# Users
export ZOO_DAEMON_USER="${APP_USER}"
export ZOO_DAEMON_GROUP="${APP_GROUP}"

# Cluster configuration
export ZOO_SERVER_ID="${ZOO_SERVER_ID:-1}"
export ZOO_PORT_NUMBER="${ZOO_CLIENT_PORT:-2181}"
export ZOO_SERVERS="${ZOO_SERVERS:-server.1=0.0.0.0:2888:3888}"

# Zookeeper settings
export ZOO_TICK_TIME="${ZOO_TICK_TIME:-2000}"
export ZOO_INIT_LIMIT="${ZOO_INIT_LIMIT:-10}"
export ZOO_SYNC_LIMIT="${ZOO_SYNC_LIMIT:-5}"
export ZOO_MAX_CNXNS="${ZOO_MAX_CNXNS:-0}"
export ZOO_MAX_CLIENT_CNXNS="${ZOO_MAX_CLIENT_CNXNS:-60}"
export ZOO_AUTOPURGE_PURGEINTERVAL="${ZOO_AUTOPURGE_PURGEINTERVAL:-0}"
export ZOO_AUTOPURGE_SNAPRETAINCOUNT="${ZOO_AUTOPURGE_SNAPRETAINCOUNT:-3}"
export ZOO_LOG_LEVEL="${ZOO_LOG_LEVEL:-INFO}"
export ZOO_4LW_COMMANDS_WHITELIST="${ZOO_4LW_COMMANDS_WHITELIST:-srvr, mntr}"
export ZOO_RECONFIG_ENABLED="${ZOO_RECONFIG_ENABLED:-no}"
export ZOO_LISTEN_ALLIPS_ENABLED="${ZOO_LISTEN_ALLIPS_ENABLED:-no}"
export ZOO_ENABLE_PROMETHEUS_METRICS="${ZOO_ENABLE_PROMETHEUS_METRICS:-no}"
export ZOO_PROMETHEUS_METRICS_PORT_NUMBER="${ZOO_PROMETHEUS_METRICS_PORT_NUMBER:-7000}"
export ZOO_STANDALONE_ENABLED=${ZOO_STANDALONE_ENABLED:-true}
export ZOO_ADMINSERVER_ENABLED=${ZOO_ADMINSERVER_ENABLED:-true}

# Zookeeper TLS Settings
export ZOO_TLS_CLIENT_ENABLE="${ZOO_TLS_CLIENT_ENABLE:-false}"
export ZOO_TLS_PORT_NUMBER="${ZOO_TLS_PORT_NUMBER:-3181}"
export ZOO_TLS_CLIENT_KEYSTORE_FILE="${ZOO_TLS_CLIENT_KEYSTORE_FILE:-}"
export ZOO_TLS_CLIENT_KEYSTORE_PASSWORD="${ZOO_TLS_CLIENT_KEYSTORE_PASSWORD:-}"
export ZOO_TLS_CLIENT_TRUSTSTORE_FILE="${ZOO_TLS_CLIENT_TRUSTSTORE_FILE:-}"
export ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD="${ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD:-}"
export ZOO_TLS_QUORUM_ENABLE="${ZOO_TLS_QUORUM_ENABLE:-false}"
export ZOO_TLS_QUORUM_KEYSTORE_FILE="${ZOO_TLS_QUORUM_KEYSTORE_FILE:-}"
export ZOO_TLS_QUORUM_KEYSTORE_PASSWORD="${ZOO_TLS_QUORUM_KEYSTORE_PASSWORD:-}"
export ZOO_TLS_QUORUM_TRUSTSTORE_FILE="${ZOO_TLS_QUORUM_TRUSTSTORE_FILE:-}"
export ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD="${ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD:-}"

# Java settings
export JVMFLAGS="${ZOO_JVMFLAGS:-}"
export ZOO_HEAP_SIZE="${ZOO_HEAP_SIZE:-1024}"

# Authentication
export ZOO_ALLOW_ANONYMOUS_LOGIN="${ZOO_ALLOW_ANONYMOUS_LOGIN:-no}"
export ZOO_ENABLE_AUTH="${ZOO_ENABLE_AUTH:-no}"
export ZOO_CLIENT_USER="${ZOO_CLIENT_USER:-}"
export ZOO_SERVER_USERS="${ZOO_SERVER_USERS:-}"
EOF

    if [[ -f "${ZOO_CLIENT_PASSWORD_FILE:-}" ]]; then
        cat <<"EOF"
export ZOO_CLIENT_PASSWORD="$(< "${ZOO_CLIENT_PASSWORD_FILE}")"
EOF
    else
        cat <<"EOF"
export ZOO_CLIENT_PASSWORD="${ZOO_CLIENT_PASSWORD:-}"
EOF
    fi
    if [[ -f "${ZOO_SERVER_PASSWORDS_FILE:-}" ]]; then
        cat <<"EOF"
export ZOO_SERVER_PASSWORDS="$(< "${ZOO_SERVER_PASSWORDS_FILE}")"
EOF
    else
        cat <<"EOF"
export ZOO_SERVER_PASSWORDS="${ZOO_SERVER_PASSWORDS:-}"
EOF
    fi
}

# 将变量配置更新至配置文件
# 参数:
#   $1 - 文件
#   $2 - 变量
#   $3 - 值（列表）
zoo_common_conf_set() {
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
            zoo_common_conf_set "$file" "${key[$i]}" "${values[$i]}"
        done
    else
        value="${values[0]}"
        # Check if the value was set before
        if grep -q "^[#\\s]*$key\s*=.*" "$file"; then
            # Update the existing key
            replace_in_file "$file" "^[#\\s]*${key}\s*=.*" "${key}=${value}" false
        else
            # Add a new key
            printf '\n%s=%s' "$key" "$value" >>"$file"
        fi
    fi
}

# 更新 server.properties 配置文件中指定变量值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
zoo_conf_set() {
    zoo_common_conf_set "$ZOO_CONF_DIR/zoo.cfg" "$@"
}

# 更新 log4j.properties 配置文件中指定变量值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
zoo_log4j_set() {
    zoo_common_conf_set "$ZOO_CONF_DIR/log4j.properties" "$@"
}

# 检测用户参数信息是否满足条件
# 针对部分权限过于开放情况，可打印提示信息
app_verify_minimum_env() {
    local error_code=0
    LOG_D "Validating settings in ZOO_* env vars..."

    # Auxiliary functions
    print_validation_error() {
        LOG_E "$1"
        error_code=1
    }

    # ZooKeeper authentication validations
    if is_boolean_yes "$ZOO_ALLOW_ANONYMOUS_LOGIN"; then
        LOG_W "You have set the environment variable ZOO_ALLOW_ANONYMOUS_LOGIN=${ZOO_ALLOW_ANONYMOUS_LOGIN}. For safety reasons, do not use this flag in a production environment."
    elif ! is_boolean_yes "$ZOO_ENABLE_AUTH"; then
        print_validation_error "The ZOO_ENABLE_AUTH environment variable does not configure authentication. Set the environment variable ZOO_ALLOW_ANONYMOUS_LOGIN=yes to allow unauthenticated users to connect to ZooKeeper."
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

# 加载在后续脚本命令中使用的参数信息，包括从"*_FILE"文件中导入的配置
# 必须在其他函数使用前调用
docker_setup_env() {
	# 尝试从文件获取环境变量的值
	# file_env 'ENV_VAR_NAME'

	# 尝试从文件获取环境变量的值，如果不存在，使用默认值 default_val 
	# file_env 'ENV_VAR_NAME' 'default_val'

	# 检测变量 ENV_VAR_NAME 未定义或值为空，赋值为默认值：default_val
	# : "${ENV_VAR_NAME:=default_val}"
    : 
}

# 生成默认配置文件
# 全局变量:
#   ZOO_*
zoo_generate_conf() {
    cp "${ZOO_CONF_DIR}/zoo_sample.cfg" "$ZOO_CONF_FILE"
    echo >> "$ZOO_CONF_FILE"

    zoo_conf_set "tickTime" "$ZOO_TICK_TIME"
    zoo_conf_set "initLimit" "$ZOO_INIT_LIMIT"
    zoo_conf_set "syncLimit" "$ZOO_SYNC_LIMIT"
    zoo_conf_set "dataDir" "$ZOO_DATA_DIR"
    zoo_conf_set "dataLogDir" "${ZOO_DATA_LOG_DIR}"
    zoo_conf_set "clientPort" "$ZOO_PORT_NUMBER"
    zoo_conf_set "maxCnxns" "$ZOO_MAX_CNXNS"
    zoo_conf_set "maxClientCnxns" "$ZOO_MAX_CLIENT_CNXNS"
    zoo_conf_set "standaloneEnabled" "$ZOO_STANDALONE_ENABLED"
    zoo_conf_set "reconfigEnabled" "$(is_boolean_yes "$ZOO_RECONFIG_ENABLED" && echo true || echo false)"
    zoo_conf_set "quorumListenOnAllIPs" "$(is_boolean_yes "$ZOO_LISTEN_ALLIPS_ENABLED" && echo true || echo false)"
    zoo_conf_set "autopurge.purgeInterval" "$ZOO_AUTOPURGE_PURGEINTERVAL"
    zoo_conf_set "autopurge.snapRetainCount" "$ZOO_AUTOPURGE_SNAPRETAINCOUNT"
    zoo_conf_set "4lw.commands.whitelist" "$ZOO_4LW_COMMANDS_WHITELIST"

    if is_boolean_yes "${ZOO_ADMINSERVER_ENABLED}"; then
        zoo_conf_set "admin.enableServer" true
        zoo_conf_set "admin.serverAddress" "0.0.0.0"
        zoo_conf_set "admin.serverPort" 8080
        zoo_conf_set "admin.idleTimeout" 30000
        zoo_conf_set "admin.commandURL" "/commands"
    fi

    # Set log level
    zoo_log4j_set "zookeeper.console.threshold" "$ZOO_LOG_LEVEL"
    zoo_log4j_set "zookeeper.log.dir" "${ZOO_LOG_DIR}"

    # Add zookeeper servers to configuration
    read -r -a zookeeper_servers_list <<< "${ZOO_SERVERS//[;, ]/ }"
    if [[ ${#zookeeper_servers_list[@]} -gt 1 ]]; then
#        local i=1
        for server in "${zookeeper_servers_list[@]}"; do
            LOG_I "Adding server: ${server}"
            read -r -a server_info <<< "${server//=/ }"
            zoo_conf_set "${server_info[0]}" "${server_info[1]};${ZOO_PORT_NUMBER}"
#            (( i++ ))
        done
    else
        LOG_I "No additional servers were specified. ZooKeeper will run in standalone mode..."
    fi

    # If TLS in enable
    if is_boolean_yes "${ZOO_TLS_CLIENT_ENABLE}"; then
        zoo_conf_set "client.secure" true
        zoo_conf_set "secureClientPort" "$ZOO_TLS_PORT_NUMBER"
        zoo_conf_set "serverCnxnFactory" "org.apache.zookeeper.server.NettyServerCnxnFactory"
        zoo_conf_set "ssl.keyStore.location" "$ZOO_TLS_CLIENT_KEYSTORE_FILE"
        zoo_conf_set "ssl.keyStore.password" "$ZOO_TLS_CLIENT_KEYSTORE_PASSWORD"
        zoo_conf_set "ssl.trustStore.location" "$ZOO_TLS_CLIENT_TRUSTSTORE_FILE"
        zoo_conf_set "ssl.trustStore.password" "$ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD"
    fi
    if is_boolean_yes "${ZOO_TLS_QUORUM_ENABLE}"; then
        zoo_conf_set "sslQuorum" true
        zoo_conf_set "serverCnxnFactory" "org.apache.zookeeper.server.NettyServerCnxnFactory"
        zoo_conf_set "ssl.quorum.keyStore.location" "$ZOO_TLS_QUORUM_KEYSTORE_FILE"
        zoo_conf_set "ssl.quorum.keyStore.password" "$ZOO_TLS_QUORUM_KEYSTORE_PASSWORD"
        zoo_conf_set "ssl.quorum.trustStore.location" "$ZOO_TLS_QUORUM_TRUSTSTORE_FILE"
        zoo_conf_set "ssl.quorum.trustStore.password" "$ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD"
    fi
}

# 设置环境变量 JVMFLAGS
# 全局变量:
#   JVMFLAGS
# 参数:
#   $1 - value
zoo_export_jvmflags() {
    local -r value="${1:?value is required}"

    export JVMFLAGS="${JVMFLAGS} ${value}"
    echo "export JVMFLAGS=\"${JVMFLAGS}\"" > "${ZOO_CONF_DIR}/java.env"
}

# 配置 HEAP 大小
# 全局变量:
#   JVMFLAGS
# 参数:
#   $1 - HEAP 大小
zoo_configure_heap_size() {
    local -r heap_size="${1:?heap_size is required}"

    if [[ "$JVMFLAGS" =~ -Xm[xs].*-Xm[xs] ]]; then
        LOG_D "Using specified values (JVMFLAGS=${JVMFLAGS})"
    else
        LOG_D "Setting '-Xmx${heap_size}m -Xms${heap_size}m' heap options..."
        zoo_export_jvmflags "-Xmx${heap_size}m -Xms${heap_size}m"
    fi
}

# 配置 zookeeper 启用认证
# 全局变量:
#   ZOO_CONF_FILE
zoo_enable_authentication() {
    LOG_I "Enabling authentication..."
    zoo_conf_set "authProvider.1" "org.apache.zookeeper.server.auth.SASLAuthenticationProvider"
    zoo_conf_set "requireClientAuthScheme" sasl
}

# 为 zookeeper 认证创建 JAAS 配置文件
# 全局变量:
#   JVMFLAGS, ZOO_*
zoo_create_jaas_file() {
    LOG_I "Creating jaas file..."
    read -r -a server_users_list <<< "${ZOO_SERVER_USERS//[;, ]/ }"
    read -r -a server_passwords_list <<< "${ZOO_SERVER_PASSWORDS//[;, ]/ }"

    local zoo_server_user_passwords=""
    for i in $(seq 0 $(( ${#server_users_list[@]} - 1 ))); do
        zoo_server_user_passwords="${zoo_server_user_passwords}\n   user_${server_users_list[i]}=\"${server_passwords_list[i]}\""
    done
    zoo_server_user_passwords="${zoo_server_user_passwords#\\n   };"

    cat >"${ZOO_CONF_DIR}/zoo_jaas.conf" <<EOF
Client {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    username="$ZOO_CLIENT_USER"
    password="$ZOO_CLIENT_PASSWORD";
};
Server {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    $(echo -e -n "${zoo_server_user_passwords}")
};
EOF
    zoo_export_jvmflags "-Djava.security.auth.login.config=${ZOO_CONF_DIR}/zoo_jaas.conf"

    # Restrict file permissions
    _is_run_as_root && ensure_owned_by "${ZOO_CONF_DIR}/zoo_jaas.conf" "$ZOO_DAEMON_USER"
    chmod 400 "${ZOO_CONF_DIR}/zoo_jaas.conf"
}

# Enable Prometheus metrics for ZooKeeper
# 全局变量:
#   ZOO_PROMETHEUS_METRICS_PORT_NUMBER
#   ZOO_CONF_FILE
zoo_enable_prometheus_metrics() {
    LOG_I "Enabling Prometheus metrics..."
    zoo_conf_set "metricsProvider.className" "org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider"
    zoo_conf_set "metricsProvider.httpPort" "$ZOO_PROMETHEUS_METRICS_PORT_NUMBER"
    zoo_conf_set "metricsProvider.exportJvmInfo" true
}

# 以后台方式启动Zookeeper服务，并等待启动就绪
# 全局变量:
#   ZOO_*
zoo_start_server_bg() {
    local start_command="zkServer.sh start"
    LOG_I "Starting ZooKeeper in background..."
    _is_run_as_root && start_command="gosu ${ZOO_DAEMON_USER} ${start_command}"
    if is_boolean_yes "${ENV_DEBUG}"; then
        $start_command
    else
        $start_command >/dev/null 2>&1
    fi
    # 检测端口是否就绪
    wait-for-port --timeout 60 "$ZOO_PORT_NUMBER"
}

########################
# Stop ZooKeeper
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zoo_stop_server() {
    LOG_I "Stopping ZooKeeper..."
    if [[ "$ENV_DEBUG" = true ]]; then
        "zkServer.sh" stop
    else
        "zkServer.sh" stop >/dev/null 2>&1
    fi
}

# 配置 ACL 参数
# 全局变量:
#   ZOO_*
zoo_configure_acl() {
    local acl_string=""
    for server_user in ${ZOO_SERVER_USERS//[;, ]/ }; do
        acl_string="${acl_string},sasl:${server_user}:crdwa"
    done
    acl_string="${acl_string#,}"

    zoo_start_server_bg

    for path in / /zookeeper /zookeeper/quota; do
        LOG_I "Setting the ACL rule '${acl_string}' in ${path}"
        retry_while "${ZOO_BIN_DIR}/zkCli.sh setAcl ${path} ${acl_string}" 80
    done

    zoo_stop_server
    mv "${ZOO_LOG_DIR}/zookeeper.out" "${ZOO_LOG_DIR}/zookeeper.out.firstboot"
}

# 应用默认初始化操作
docker_app_init() {
    LOG_I "Initializing ${APP_NAME}..."

    # 检测配置文件是否存在
    if [[ ! -f "$ZOO_CONF_FILE" || ! -f "/srv/data/${APP_NAME}/app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
        zoo_generate_conf
        zoo_configure_heap_size "$ZOO_HEAP_SIZE"
        if is_boolean_yes "$ZOO_ENABLE_AUTH"; then
            zoo_enable_authentication
            zoo_create_jaas_file
        fi
        if is_boolean_yes "$ZOO_ENABLE_PROMETHEUS_METRICS"; then
            zoo_enable_prometheus_metrics
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > /srv/data/${APP_NAME}/app_init_flag
    else
        LOG_I "User injected custom configuration detected!"
    fi

    if is_dir_empty "$ZOO_DATA_DIR" || [[ ! -f "/srv/data/${APP_NAME}/data_init_flag" ]]; then
        LOG_I "Deploying ZooKeeper from scratch..."
        echo "$ZOO_SERVER_ID" > "${ZOO_DATA_DIR}/myid"

        if is_boolean_yes "$ZOO_ENABLE_AUTH" && [[ $ZOO_SERVER_ID -eq 1 ]] && [[ -n $ZOO_SERVER_USERS ]]; then
            zoo_configure_acl
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > /srv/data/${APP_NAME}/data_init_flag
    else
        LOG_I "Deploying ZooKeeper with persisted data..."
    fi
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，会在 /srv/data/${APP_NAME} 目录中生成 custom_init_flag 文件
docker_custom_init() {
    # 检测用户配置文件目录是否存在initdb.d文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，进行初始化操作
    	if [ ! -f "/srv/data/${APP_NAME}/custom_init_flag" ]; then
            LOG_I "Process custom init scripts for ${APP_NAME}..."

    		# 检测目录权限，防止初始化失败
    		ls "/srv/conf/${APP_NAME}/initdb.d/" > /dev/null

    		docker_process_init_files /srv/conf/${APP_NAME}/initdb.d/*

    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > /srv/data/${APP_NAME}/custom_init_flag
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi
}
