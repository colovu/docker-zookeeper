#!/bin/bash -e

# 在安装完应用后，使用该脚本修改默认配置文件中部分配置项
# 如果相应的配置项已经定义整体环境变量，则不需要在这里修改
echo "Process overrides for default configs..."
#sed -i -E 's/^listeners=/d' "$KAFKA_HOME/config/server.properties"

# 修改默认Log输出目录
#sed -i -E 's/^log.dirs=\/tmp\/kafka-logs*/log.dirs=\/var\/log\/kafka/g' "$KAFKA_HOME/config/server.properties"