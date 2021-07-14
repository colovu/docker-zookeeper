#!/bin/bash
# Ver: 1.0 by Endial Fang (endial@126.com)
# 
# 应用环境变量定义及初始化

# 通用设置
export ENV_DEBUG=${ENV_DEBUG:-false}
export ALLOW_ANONYMOUS_LOGIN="${ALLOW_ANONYMOUS_LOGIN:-no}"

# 通过读取变量名对应的 *_FILE 文件，获取变量值；如果对应文件存在，则通过传入参数设置的变量值会被文件中对应的值覆盖
# 变量优先级： *_FILE > 传入变量 > 默认值
app_env_file_lists=(
	ZOO_CLIENT_PASSWORD
	ZOO_SERVER_PASSWORDS
)
for env_var in "${app_env_file_lists[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        export "${env_var}=$(< "${!file_env_var}")"
        unset "${file_env_var}"
    fi
done
unset app_env_file_lists

# 应用路径参数
export APP_HOME_DIR="/usr/local/${APP_NAME}"
export APP_DEF_DIR="/etc/${APP_NAME}"
export APP_CONF_DIR="/srv/conf/${APP_NAME}"
export APP_DATA_DIR="/srv/data/${APP_NAME}"
export APP_DATA_LOG_DIR="/srv/datalog/${APP_NAME}"
export APP_CACHE_DIR="/var/cache/${APP_NAME}"
export APP_RUN_DIR="/var/run/${APP_NAME}"
export APP_LOG_DIR="/var/log/${APP_NAME}"
export APP_CERT_DIR="/srv/cert/${APP_NAME}"


# 应用配置参数
# Paths configuration
export ZOO_CONF_FILE="${APP_CONF_DIR}/zoo.cfg"

# Enviroment for zkServer.sh
export ZOO_LOG_DIR=${APP_LOG_DIR}
export ZOO_DATADIR=${APP_DATA_DIR}
export ZOO_DATALOGDIR=${APP_DATA_LOG_DIR}
export ZOOCFGDIR=${APP_CONF_DIR}
export ZOOPIDFILE=${APP_RUN_DIR}/zookeeper_server.pid
export ZOO_LOG4J_PROP="${ZOO_LOG4J_PROP:-INFO,CONSOLE}"

# Application settings
export ZOO_PORT_NUMBER="${ZOO_PORT_NUMBER:-2181}"
export ZOO_TICK_TIME="${ZOO_TICK_TIME:-2000}"
export ZOO_INIT_LIMIT="${ZOO_INIT_LIMIT:-10}"
export ZOO_SYNC_LIMIT="${ZOO_SYNC_LIMIT:-5}"
export ZOO_MAX_CNXNS="${ZOO_MAX_CNXNS:-0}"
export ZOO_MAX_CLIENT_CNXNS="${ZOO_MAX_CLIENT_CNXNS:-60}"
export ZOO_AUTOPURGE_PURGEINTERVAL="${ZOO_AUTOPURGE_PURGEINTERVAL:-0}"
export ZOO_AUTOPURGE_SNAPRETAINCOUNT="${ZOO_AUTOPURGE_SNAPRETAINCOUNT:-3}"
export ZOO_4LW_COMMANDS_WHITELIST="${ZOO_4LW_COMMANDS_WHITELIST:-srvr, mntr}"
export ZOO_RECONFIG_ENABLED="${ZOO_RECONFIG_ENABLED:-no}"
export ZOO_LISTEN_ALLIPS_ENABLED="${ZOO_LISTEN_ALLIPS_ENABLED:-no}"
export ZOO_ENABLE_PROMETHEUS_METRICS="${ZOO_ENABLE_PROMETHEUS_METRICS:-no}"
export ZOO_PROMETHEUS_METRICS_PORT_NUMBER="${ZOO_PROMETHEUS_METRICS_PORT_NUMBER:-7000}"
export ZOO_STANDALONE_ENABLED=${ZOO_STANDALONE_ENABLED:-true}
export ZOO_ADMINSERVER_ENABLED=${ZOO_ADMINSERVER_ENABLED:-true}

# Cluster configuration
export ZOO_SERVER_ID="${ZOO_SERVER_ID:-1}"
export ZOO_SERVERS="${ZOO_SERVERS:-server.1=0.0.0.0:2888:3888}"

# Application TLS Settings
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

# Java Settings
export JVMFLAGS="${JVMFLAGS:-}"
export HEAP_SIZE="${HEAP_SIZE:-1024}"

# Authentication
export ZOO_ENABLE_AUTH="${ZOO_ENABLE_AUTH:-no}"
export ZOO_CLIENT_USER="${ZOO_CLIENT_USER:-}"
export ZOO_CLIENT_PASSWORD="${ZOO_CLIENT_PASSWORD:-}"
export ZOO_SERVER_USERS="${ZOO_SERVER_USERS:-}"
export ZOO_SERVER_PASSWORDS="${ZOO_SERVER_PASSWORDS:-}"

# 内部变量
export APP_PID_FILE="${ZOOPIDFILE}"

export APP_DAEMON_USER="${APP_NAME}"
export APP_DAEMON_GROUP="${APP_NAME}"

# 个性化变量

