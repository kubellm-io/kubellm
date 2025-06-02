#!/usr/bin/env bash

# Copyright 2025 The Kubellm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 日志输出相关函数库

# 日志级别: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR, 4=FATAL
LOG_LEVEL="${LOG_LEVEL:-1}"

# 检测终端是否支持彩色输出
if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM}" != "dumb" ] && [ "${NO_COLOR:-}" != "true" ]; then
  COLOR_RED="\033[0;31m"
  COLOR_GREEN="\033[0;32m"
  COLOR_YELLOW="\033[0;33m"
  COLOR_BLUE="\033[0;34m"
  COLOR_PURPLE="\033[0;35m"
  COLOR_CYAN="\033[0;36m"
  COLOR_RESET="\033[0m"
else
  # 禁用颜色
  COLOR_RED=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_PURPLE=""
  COLOR_CYAN=""
  COLOR_RESET=""
fi

# Windows CMD特殊处理
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  # 尝试为Windows命令行启用ANSI支持
  if command -v powershell.exe &> /dev/null; then
    powershell.exe -command "Set-ItemProperty HKCU:\Console VirtualTerminalLevel -Type DWORD 1" &> /dev/null || true
  fi
fi

# 日志格式化函数
kubellm::log::format() {
  local timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
  echo -e "${timestamp} $1"
}

# 调试日志
kubellm::log::debug() {
  if [[ "${LOG_LEVEL}" -le 0 ]]; then
    kubellm::log::format "${COLOR_BLUE}[DEBUG]${COLOR_RESET} $*"
  fi
}

# 信息日志
kubellm::log::info() {
  if [[ "${LOG_LEVEL}" -le 1 ]]; then
    kubellm::log::format "${COLOR_GREEN}[INFO]${COLOR_RESET} $*"
  fi
}

# 警告日志
kubellm::log::warn() {
  if [[ "${LOG_LEVEL}" -le 2 ]]; then
    kubellm::log::format "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
  fi
}

# 错误日志
kubellm::log::error() {
  if [[ "${LOG_LEVEL}" -le 3 ]]; then
    kubellm::log::format "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
  fi
}

# 致命错误日志并退出
kubellm::log::fatal() {
  kubellm::log::format "${COLOR_RED}[FATAL]${COLOR_RESET} $*" >&2
  exit 1
}

# 计时开始
kubellm::log::start_timer() {
  TIMER_START=$(date +%s)
  TIMER_NAME="${1:-操作}"
  kubellm::log::info "开始 ${TIMER_NAME}..."
}

# 计时结束
kubellm::log::end_timer() {
  local duration=$(($(date +%s) - TIMER_START))
  kubellm::log::info "${TIMER_NAME} 完成，耗时 ${duration} 秒"
}

# 进度条函数
kubellm::log::progress_bar() {
  local current=$1
  local total=$2
  local prefix="${3:-Progress:}"
  local suffix="${4:-%}"
  local bar_length=40
  
  local percent=$((current * 100 / total))
  local filled_length=$((bar_length * current / total))
  local bar=""
  
  for ((i=0; i<filled_length; i++)); do
    bar="${bar}="
  done
  
  for ((i=filled_length; i<bar_length; i++)); do
    bar="${bar}."
  done
  
  printf "\r%s [%s] %d%s " "$prefix" "$bar" "$percent" "$suffix"
  
  if [[ $current -eq $total ]]; then
    echo
  fi
}