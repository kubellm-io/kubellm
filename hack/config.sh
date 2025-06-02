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

# ============================================
# 代码生成工具配置文件
# 此文件为用户提供自定义配置，会被 init.sh 引用
# 修改此文件可以覆盖默认配置
# ============================================

# 项目配置
ROOT_PACKAGE="github.com/kubellm-io/kubellm"  # 项目根包名，默认从go.mod获取

# API配置
# API_ROOT="${PROJECT_ROOT}/pkg/apis"  # API目录路径
# API_GROUPS=""  # 手动指定API组，默认为空时会自动扫描
# APIS_PKG="${ROOT_PACKAGE}/pkg/apis"  # API包路径

# 生成配置
# OUTPUT_BASE="${PROJECT_ROOT}/_output"  # 输出基础目录
# CLIENT_ROOT="${PROJECT_ROOT}/pkg/client"  # 客户端代码输出目录
# CLIENT_PKG="${ROOT_PACKAGE}/pkg/client"  # 客户端包路径
BOILERPLATE="${HACK_ROOT}/boilerplate/boilerplater.go.txt"  # 代码头部注释模板

# CRD 配置
# CRD_OPTIONS="crd:trivialVersions=true,preserveUnknownFields=false"  # CRD生成选项
# CRD_OUTPUT_DIR="${PROJECT_ROOT}/config/crd/bases"  # CRD输出目录

# Protobuf 配置
# PROTO_ROOT="${PROJECT_ROOT}/api"  # Protobuf文件根目录
# PROTO_OUTPUT="${OUTPUT_BASE}/generated/proto"  # Protobuf生成输出目录

# 工具配置
# TOOLS_BIN_DIR="${OUTPUT_BASE}/tools/bin"  # 工具二进制目录

# 功能开关 - 设置为 true 或 false
# ENABLE_DEEPCOPY="true"  # 生成DeepCopy代码
ENABLE_DEEPCOPY_INTERNAL="true"  # 生成内部版本DeepCopy代码
# ENABLE_REGISTER="true"  # 生成Register代码
# ENABLE_DEFAULTER="true"  # 生成Defaulter代码
ENABLE_CONVERSION="true"  # 生成Conversion代码
ENABLE_VALIDATION="false"  # 生成Validation代码
# ENABLE_APPLYCONFIGURATION="true"  # 生成ApplyConfiguration代码
# ENABLE_CLIENTSET="true"  # 生成Client代码
# ENABLE_LISTER="true"  # 生成Lister代码
# ENABLE_INFORMER="true"  # 生成Informer代码
# ENABLE_OPENAPI="true"  # 生成OpenAPI代码
# ENABLE_CRD="true"  # 生成CRD清单
ENABLE_PROTOBUF="${ENABLE_PROTOBUF:-false}"  # 生成Protobuf代码

# Protobuf输出目录
PROTO_OUTPUT_DIR="${PROTO_OUTPUT_DIR:-${PROJECT_ROOT}/pkg/apis}"

# Protobuf额外参数
PROTO_EXTRA_ARGS="${PROTO_EXTRA_ARGS:-""}"

# CRD生成选项重写（可选）
CRD_GEN_OPTIONS_OVERRIDE="${CRD_GEN_OPTIONS_OVERRIDE:-""}" 
CLEAN_BEFORE="${CLEAN_BEFORE:-false}"