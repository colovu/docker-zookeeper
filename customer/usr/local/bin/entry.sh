#!/bin/bash
# Ver: 1.1 by Endial Fang (endial@126.com)
# 
# 容器入口脚本

# 设置 shell 执行参数，可使用'-'(打开）'+'（关闭）控制。常用：
# 	-e: 命令执行错误则报错; -u: 变量未定义则报错; -x: 打印实际待执行的命令行; -o pipefail: 设置管道中命令遇到失败则报错
set -eu
set -o pipefail

. /usr/local/bin/comm-${APP_NAME}.sh			# 应用专用函数库

. /usr/local/bin/comm-env.sh 			# 设置环境变量

LOG_I "** Processing entry.sh **"

if ! is_sourced; then
	# 替换命令行中的变量
	set -- $(eval echo "$@")

	[ "${1:0:1}" = '-' ] && set -- "${APP_EXEC:-}" "$@"

	print_image_welcome
	print_command_help "$@"

	if [ "$1" = "${APP_EXEC}" ] && is_root; then
    	/usr/local/bin/setup.sh

		LOG_I "Restart with non-root user: ${APP_USER}\n"
		exec gosu "${APP_USER}" "$0" "$@"
	fi

	[ "$1" = "${APP_EXEC}" ] && /usr/local/bin/init.sh

	LOG_I "Start container with command: $@"
	exec tini -- "$@"
fi
