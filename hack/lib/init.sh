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

# 初始化环境变量和依赖库
set -o errexit
set -o nounset
set -o pipefail

# 获取init.sh脚本所在目录的前两级，即kubellm根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HACK_ROOT="${PROJECT_ROOT}/hack"
LIB_ROOT="${HACK_ROOT}/lib"
CODEGEN_ROOT="${HACK_ROOT}/codegen"

# 加载依赖库
source "${LIB_ROOT}/logging.sh"
source "${LIB_ROOT}/util.sh"

# 检测操作系统和架构
OS=$(kubellm::util::get_os)
ARCH=$(kubellm::util::get_arch)

# 加载并设置配置
CONFIG_FILE="${PROJECT_ROOT}/hack/config.sh"
if [[ -f "${CONFIG_FILE}" ]]; then
  source "${CONFIG_FILE}"
fi

# 设置默认配置值（如果未在config.sh中定义）
ROOT_PACKAGE="${ROOT_PACKAGE:-$(go list -m 2>/dev/null)}"
if [[ -z "${ROOT_PACKAGE}" ]]; then
  if [[ -f "${PROJECT_ROOT}/go.mod" ]]; then
    ROOT_PACKAGE=$(grep "^module " "${PROJECT_ROOT}/go.mod" | awk '{print $2}')
  else
    kubellm::log::warn "无法确定项目的 Go 模块名，请在 config.sh 中设置 ROOT_PACKAGE"
    ROOT_PACKAGE="github.com/unknown/project"
  fi
fi

# API相关配置
API_ROOT="${API_ROOT:-${PROJECT_ROOT}/pkg/apis}"
APIS_PKG="${APIS_PKG:-${ROOT_PACKAGE}/pkg/apis}"
API_GROUPS="${API_GROUPS:-}"

# 代码生成配置
CLIENT_ROOT="${CLIENT_ROOT:-${PROJECT_ROOT}/pkg/generated}"
CLIENT_PKG="${CLIENT_PKG:-${ROOT_PACKAGE}/pkg/generated}"
BOILERPLATE="${BOILERPLATE:-${HACK_ROOT}/boilerplate/boilerplater.go.txt}"

# CRD 配置
CRD_OPTIONS="${CRD_OPTIONS:-crd:trivialVersions=true,preserveUnknownFields=false}"
CRD_OUTPUT_DIR="${CRD_OUTPUT_DIR:-${PROJECT_ROOT}/config/crds}"

# 工具配置
# OUTPUT_BASE="${OUTPUT_BASE:-${PROJECT_ROOT}/_output}"
# TOOLS_BIN_DIR="${TOOLS_BIN_DIR:-${OUTPUT_BASE}/tools/bin}"
# PATH="${TOOLS_BIN_DIR}:${PATH}"
# Protobuf 配置
PROTO_ROOT="${PROTO_ROOT:-${PROJECT_ROOT}/api}"
PROTO_OUTPUT="${PROTO_OUTPUT:-${PROJECT_ROOT}/generated/proto}"
# 创建必要的目录
# kubellm::util::ensure_dir "${OUTPUT_BASE}"
# kubellm::util::ensure_dir "${TOOLS_BIN_DIR}"
kubellm::util::ensure_dir "${CRD_OUTPUT_DIR}"


# 确保必要的功能和命令可用
kubellm::util::ensure_function_exists "kubellm::log::info" "kubellm::log::warn" "kubellm::log::error" "kubellm::log::fatal"


# 默认启用所有生成器，可以在config.sh中覆盖
ENABLE_DEEPCOPY="${ENABLE_DEEPCOPY:-true}"
ENABLE_REGISTER=${ENABLE_REGISTER:-true}        # 控制是否生成 Register 代码
ENABLE_DEFAULTER="${ENABLE_DEFAULTER:-true}"
ENABLE_CONVERSION=${ENABLE_CONVERSION:-false}    # 控制是否生成 Conversion 代码

ENABLE_VALIDATION=${ENABLE_VALIDATION:-true}    # 控制是否生成 Validation (通过 hack/codegen/validation.sh 或类似脚本)
ENABLE_CLIENTSET=${ENABLE_CLIENTSET:-true}            # 控制是否生成 Client, Lister, Informer (通过 kube::codegen::gen_client)
ENABLE_OPENAPI=${ENABLE_OPENAPI:-true}          # 控制是否生成 OpenAPI (通过 hack/codegen/direct-openapi.sh)
ENABLE_CRD=${ENABLE_CRD:-true}                  # 控制是否生成 CRD (通过 controller-gen)
ENABLE_APPLYCONFIGURATION=${ENABLE_APPLYCONFIGURATION:-true}  # 控制是否生成 ApplyConfiguration 代码
ENABLE_PROTOBUF=${ENABLE_PROTOBUF:-true}        # 控制是否生成 Protobuf 代码
ENABLE_LISTER="${ENABLE_LISTER:-true}"
ENABLE_INFORMER="${ENABLE_INFORMER:-true}"
CLEAN_BEFORE=${CLEAN_BEFORE:-true}              # 在代码生成前是否清理旧文件



# 版本控制
VERSION_FILE="${VERSION_FILE:-${PROJECT_ROOT}/VERSION}"
if [[ -f "${VERSION_FILE}" ]]; then
  VERSION=$(cat "${VERSION_FILE}")
else
  VERSION="v0.1.0-dev"
fi

# 打印初始化信息
kubellm::log::info "初始化完成，项目路径: ${PROJECT_ROOT}"
kubellm::log::info "项目模块: ${ROOT_PACKAGE}"
kubellm::log::info "操作系统: ${OS}, 架构: ${ARCH}"

# 导出所有变量，使其对子脚本可见
export SCRIPT_ROOT HACK_ROOT LIB_ROOT CODEGEN_ROOT
export OS ARCH
export ROOT_PACKAGE API_ROOT API_GROUPS APIS_PKG
export CLIENT_ROOT CLIENT_PKG BOILERPLATE
export CRD_OPTIONS CRD_OUTPUT_DIR
export PROTO_ROOT PROTO_OUTPUT
# export TOOLS_BIN_DIR
export VERSION

export ENABLE_DEEPCOPY ENABLE_REGISTER ENABLE_DEFAULTER ENABLE_CONVERSION
export ENABLE_CLIENTSET ENABLE_LISTER ENABLE_INFORMER
export ENABLE_OPENAPI ENABLE_CRD ENABLE_PROTOBUF
export  ENABLE_VALIDATION  ENABLE_APPLYCONFIGURATION CLEAN_BEFORE