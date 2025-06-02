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

# 工具函数库

# 确认脚本的函数依赖
kubellm::util::ensure_function_exists() {
  local functions=("$@")
  for func in "${functions[@]}"; do
    if ! declare -F "${func}" > /dev/null; then
      kubellm::log::fatal "缺少必要函数: ${func}"
      return 1
    fi
  done
}

# 确认命令是否存在
kubellm::util::command_exists() {
  command -v "$1" &> /dev/null
}

# 确认命令存在，否则退出
kubellm::util::ensure_command() {
  local command="$1"
  local package="${2:-$1}"
  
  if ! kubellm::util::command_exists "${command}"; then
    kubellm::log::fatal "找不到命令: ${command}，请先安装 ${package}"
    return 1
  fi
}

# 检查 Go 环境
kubellm::util::check_go_env() {
  kubellm::util::ensure_command "go" "golang"
  
  # 检查 GOPATH 是否设置
  if [[ -z "${GOPATH:-}" ]]; then
    export GOPATH="${HOME}/go"
    kubellm::log::warn "GOPATH 未设置，使用默认值: ${GOPATH}"
  fi
  
  # 检查 Go 版本
  GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
  GO_REQUIRED="1.21.0"
  
  if [[ "$(printf '%s\n' "${GO_REQUIRED}" "${GO_VERSION}" | sort -V | head -n1)" != "${GO_REQUIRED}" ]]; then
    kubellm::log::warn "Go 版本 (${GO_VERSION}) 可能不兼容，推荐使用 ${GO_REQUIRED} 或更高版本"
  else
    kubellm::log::info "检测到 Go 版本 ${GO_VERSION}"
  fi
}

# 标准化路径(处理Windows路径问题)
kubellm::util::normalize_path() {
  local path="$1"
  
  # 处理Windows路径
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # 转换为POSIX风格路径
    path=$(echo "$path" | sed 's/\\/\//g')
    
    # 将驱动器号转换为POSIX风格
    if [[ "$path" =~ ^[A-Za-z]: ]]; then
      local drive=$(echo "${path:0:1}" | tr '[:upper:]' '[:lower:]')
      path="/${drive}${path:2}"
    fi
  fi
  
  # 去除路径末尾的斜杠
  path="${path%/}"
  
  echo "$path"
}

# 获取绝对路径
kubellm::util::get_absolute_path() {
  local path="$1"
  local normalized_path=$(kubellm::util::normalize_path "$path")
  
  # 如果是相对路径，转换为绝对路径
  if [[ "${normalized_path}" != /* ]]; then
    normalized_path="${PWD}/${normalized_path}"
  fi
  
  echo "$normalized_path"
}

# 检查并创建目录
kubellm::util::ensure_dir() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}" || kubellm::log::fatal "无法创建目录: ${dir}"
  fi
}

# 清空并创建目录
kubellm::util::clean_dir() {
  local dir="$1"
  if [[ -d "${dir}" ]]; then
    rm -rf "${dir}" || kubellm::log::warn "无法删除目录: ${dir}"
  fi
  mkdir -p "${dir}" || kubellm::log::fatal "无法创建目录: ${dir}"
}

# 获取相对路径
kubellm::util::rel_path() {
  local target="$1"
  local base="$2"
  
  python3 -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null || echo "$target"
}

# 检查操作系统类型
kubellm::util::get_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux";;
    Darwin*) echo "darwin";;
    CYGWIN*|MINGW*|MSYS*|Windows*) echo "windows";;
    *)       echo "unknown";;
  esac
}

# 检查架构类型
kubellm::util::get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64";;
    arm64|aarch64) echo "arm64";;
    i?86) echo "386";;
    *) echo "unknown";;
  esac
}

# 解析YAML文件(需要yq工具)
kubellm::util::parse_yaml() {
  local file="$1"
  local key="$2"
  
  if kubellm::util::command_exists "yq"; then
    yq eval "${key}" "${file}" 2>/dev/null
  else
    kubellm::log::warn "找不到yq命令，无法解析YAML文件。请安装: go install github.com/mikefarah/yq/v4@latest"
    return 1
  fi
}

# 解析JSON文件
kubellm::util::parse_json() {
  local file="$1"
  local key="$2"
  
  if kubellm::util::command_exists "jq"; then
    jq -r "${key}" "${file}" 2>/dev/null
  else
    kubellm::log::warn "找不到jq命令，无法解析JSON文件。请安装jq"
    return 1
  fi
}

# 等待进程完成，超时处理
kubellm::util::wait_for_process() {
  local pid="$1"
  local timeout_seconds="${2:-300}"
  local description="${3:-进程}"
  
  local elapsed=0
  while kill -0 "${pid}" &>/dev/null; do
    sleep 1
    ((elapsed++))
    
    if [[ "${elapsed}" -gt "${timeout_seconds}" ]]; then
      kubellm::log::warn "${description} (PID: ${pid}) 超时，已运行 ${timeout_seconds} 秒"
      return 1
    fi
    
    if [[ $((elapsed % 10)) -eq 0 ]]; then
      kubellm::log::info "等待 ${description} 完成，已耗时 ${elapsed} 秒..."
    fi
  done
}

# 运行命令并带有超时设置
kubellm::util::run_with_timeout() {
  local timeout_seconds="$1"
  shift
  
  local temp_file=$(mktemp)
  "$@" &> "${temp_file}" &
  local pid=$!
  
  if kubellm::util::wait_for_process "${pid}" "${timeout_seconds}" "命令 $1"; then
    cat "${temp_file}"
    rm "${temp_file}"
    return 0
  else
    kill -9 "${pid}" &>/dev/null || true
    kubellm::log::error "命令超时: $1"
    kubellm::log::info "部分输出:"
    tail -n 20 "${temp_file}"
    rm "${temp_file}"
    return 1
  fi
}

# 查找项目根目录
kubellm::util::find_repo_root() {
  local dir="${1:-$PWD}"
  
  while [[ "${dir}" != "/" ]]; do
    if [[ -d "${dir}/.git" || -f "${dir}/go.mod" ]]; then
      echo "${dir}"
      return 0
    fi
    dir=$(dirname "${dir}")
  done
  
  echo "${1:-$PWD}"
  return 1
}

# 确保样板文件存在并可用
kubellm::util::ensure_boilerplate() {
  local file="${1:-${HACK_ROOT}/boilerplate.go.txt}"
  
  if [[ ! -f "${file}" ]]; then
    kubellm::log::error "缺少样板文件: ${file}"
    # 如果是go样板文件，创建一个默认的
    if [[ "${file}" == *go.txt ]]; then
      kubellm::log::info "创建默认Go样板文件..."
      cat > "${file}" << 'EOF'
/*
Copyright 2025 The Kubellm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
EOF
  fi
  fi
}

# 从文件扩展名查找相应的样板文件
kubellm::util::find_boilerplate_for_file() {
  local target_file="$1"
  local ext="${target_file##*.}"
  local boilerplate_file=""
  
  # 根据文件扩展名查找对应的样板文件
  case "${ext}" in
    go)
      boilerplate_file="${HACK_ROOT}/boilerplate.go.txt"
      ;;
    sh|bash)
      boilerplate_file="${HACK_ROOT}/boilerplate.sh.txt"
      ;;
    py|python)
      boilerplate_file="${HACK_ROOT}/boilerplate.py.txt"
      ;;
    *)
      # 默认使用Go样板
      boilerplate_file="${HACK_ROOT}/boilerplate.go.txt"
      ;;
  esac
  
  # 检查文件是否存在，不存在则尝试使用默认的go样板
  if [[ ! -f "${boilerplate_file}" ]]; then
    boilerplate_file="${HACK_ROOT}/boilerplate.go.txt"
  fi
  
  echo "${boilerplate_file}"
}