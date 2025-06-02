#!/usr/bin/env bash

# Copyright 2020 The Kubernetes Authors.
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

# 统一的代码生成入口脚本，调用各个子生成脚本或函数

set -o errexit
set -o nounset
set -o pipefail



# 脚本根目录
CURRENT_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# 加载初始化脚本，设置环境变量并导入库函数
# shellcheck source=./lib/init.sh
source "${CURRENT_PROJECT_ROOT}/lib/init.sh"
# 加载Kubernetes代码生成函数库
# shellcheck source=./codegen/kube_codegen.sh
source "${CURRENT_PROJECT_ROOT}/codegen/kube_codegen.sh"

# 打印功能开关状态
kubellm::log::info "代码生成功能开关状态:"
kubellm::log::info "  - ENABLE_DEEPCOPY: ${ENABLE_DEEPCOPY}"
kubellm::log::info "  - ENABLE_DEEPCOPY_INTERNAL: ${ENABLE_DEEPCOPY_INTERNAL}"
kubellm::log::info "  - ENABLE_REGISTER: ${ENABLE_REGISTER}"
kubellm::log::info "  - ENABLE_DEFAULTER: ${ENABLE_DEFAULTER}"
kubellm::log::info "  - ENABLE_CONVERSION: ${ENABLE_CONVERSION}"
kubellm::log::info "  - ENABLE_VALIDATION: ${ENABLE_VALIDATION}"
kubellm::log::info "  - ENABLE_APPLYCONFIGURATION: ${ENABLE_APPLYCONFIGURATION}"
kubellm::log::info "  - ENABLE_CLIENTSET: ${ENABLE_CLIENTSET}"
kubellm::log::info "  - ENABLE_LISTER: ${ENABLE_LISTER}"
kubellm::log::info "  - ENABLE_INFORMER: ${ENABLE_INFORMER}"
kubellm::log::info "  - ENABLE_OPENAPI: ${ENABLE_OPENAPI}"
kubellm::log::info "  - ENABLE_CRD: ${ENABLE_CRD}"
kubellm::log::info "  - ENABLE_PROTOBUF: ${ENABLE_PROTOBUF}"
kubellm::log::info "  - CLEAN_BEFORE: ${CLEAN_BEFORE}"

# 1. 确保依赖一致性
kubellm::log::info "更新关键依赖..."
# go get  k8s.io/client-go/gentype
go mod tidy

# 清理旧的生成文件
if [[ "${CLEAN_BEFORE}" == "true" ]]; then
  kubellm::log::info "清理旧的生成文件..."
  # 确保 pkg/generated 目录存在，以便 find 命令不会报错
    mkdir -p "${CLIENT_PKG}"

  # 清理 Go 生成文件
  find "${API_ROOT}" "${CLIENT_PKG}"  -type f \( -name 'zz_generated.*.go' -o -name '*.pb.go' \) -not -path "*/vendor/*" -delete
  # 清理 CRD YAML 文件
  find "${CRD_OUTPUT_DIR}" -name "*.yaml" -delete 2>/dev/null || true
fi

# 确保样板文件存在
kubellm::util::ensure_boilerplate "${BOILERPLATE}"

# 按照正确顺序生成代码
# 1. 基础类型代码生成 (DeepCopy, Register)

if [[ "${ENABLE_DEEPCOPY}" == "true" ]]; then
  kubellm::log::info "生成基础类型代码 (DeepCopy for external versions)..."
  kube::codegen::gen_deepcopy # 这个只处理外部版本
else
  kubellm::log::info "跳过外部版本 DeepCopy 代码生成..."
fi

# 生成 Register 代码 (如果启用，针对外部版本)
if [[ "${ENABLE_REGISTER}" == "true" ]]; then
  kubellm::log::info "生成 Register 代码 (for external versions)..."
  kube::codegen::gen_register # 这个也只处理外部版本
else
  kubellm::log::info "跳过外部版本 Register 代码生成..."
fi
  \



# 新增：为内部版本生成 DeepCopy 和 Register
# 确保在外部版本生成后，或者根据依赖关系调整顺序
# 内部版本的生成函数会自己检查 ENABLE_DEEPCOPY 和 ENABLE_REGISTER
if [[ "${ENABLE_DEEPCOPY_INTERNAL}" == "true" ]]; then
  kubellm::log::info "生成内部版本 API 的 DeepCopy 和 Register 代码..."
  kube::codegen::find_internal_api_packages # 需要先查找内部包，供 generate_internal_apis_deepcopy_and_register 使用
  kube::codegen::generate_internal_apis_deepcopy_and_register
else
  kubellm::log::info "跳过内部版本 DeepCopy 和 Register 代码生成..."
fi

if [[ "${ENABLE_DEFAULTER}" == "true" ]]; then
  kubellm::log::info "生成 Defaulter 代码..."
  kube::codegen::gen_defaulter
else
  kubellm::log::info "跳过 Defaulter 代码生成..."
fi

# conversion 代码
if [[ "${ENABLE_CONVERSION}" == "true" ]]; then
  kubellm::log::info "生成 Conversion 代码..."
  kube::codegen::gen_conversion
else
  kubellm::log::info "跳过 Conversion 代码生成..."
fi

# 生成 Validation 代码
if [[ "${ENABLE_VALIDATION}" == "true" ]]; then
  kubellm::log::info "生成 Validation 代码..."
  "${PROJECT_ROOT}/codegen/update-codegen-validation.sh" # 假设存在此脚本
else
  kubellm::log::info "跳过 Validation 代码生成..."
fi

# 生成 ApplyConfiguration 代码（如果启用）
if [[ "${ENABLE_APPLYCONFIGURATION}" == "true" ]]; then
  kubellm::log::info "生成 ApplyConfiguration 代码..."
  kube::codegen::gen_applyconfiguration
  # 如果需要单独生成，可以添加专门的函数调用
  # kubellm::log::info "ApplyConfiguration 代码已作为客户端代码生成的一部分生成"

else
  kubellm::log::info "跳过 ApplyConfiguration 代码生成..."
fi


# 生成 ClientSet 代码
if [[ "${ENABLE_CLIENTSET}" == "true" ]]; then
  kubellm::log::info "生成 ClientSet 代码..."
  # 使用 kube_codegen.sh 提供的函数
  kube::codegen::gen_clientset
else
  kubellm::log::info "跳过 ClientSet 代码生成..."
fi

# 生成 Lister 代码
if [[ "${ENABLE_LISTER}" == "true" ]]; then
  kubellm::log::info "生成 Lister 代码..."
  kube::codegen::gen_lister
else
  kubellm::log::info "跳过 Lister 代码生成..."
fi

# 生成 Informer 代码
if [[ "${ENABLE_INFORMER}" == "true" ]]; then
  kubellm::log::info "生成 Informer 代码..."
  kube::codegen::gen_informer
else
  kubellm::log::info "跳过 Informer 代码生成..."
fi

# 6. 生成 OpenAPI
kubellm::log::info "6. 生成 OpenAPI 规范代码..."
if [[ "${ENABLE_OPENAPI}" == "true" ]]; then
  kube::codegen::gen_openapi
  
  # 验证生成结果
  if [[ -f "${CLIENT_OUTPUT_DIR}/openapi/zz_generated.openapi.go" ]]; then
    kubellm::log::info "✓ OpenAPI 生成成功"
  else
    kubellm::log::error "✗ OpenAPI 生成失败"
  fi
else
  kubellm::log::info "跳过 OpenAPI 代码生成..."
fi

# 7. 生成 CRD
kubellm::log::info "7. 生成 CRD 清单文件..."
if [[ "${ENABLE_CRD}" == "true" ]]; then
  # 确保 controller-gen 可执行
  kubellm::util::ensure_command controller-gen

  # 使用 controller-gen 生成 CRD
  kube::codegen::gen_crd
  
  # 验证生成结果
  if [[ -d "${CRD_OUTPUT_DIR}" && $(find "${CRD_OUTPUT_DIR}" -name "*.yaml" | wc -l) -gt 0 ]]; then
    kubellm::log::info "✓ CRD 生成成功"
    # 显示生成的 CRD 文件
    for crd_file in $(find "${CRD_OUTPUT_DIR}" -name "*.yaml" -exec basename {} \;); do
      kubellm::log::info "  - ${crd_file}"
    done
  else
    kubellm::log::error "✗ CRD 生成失败或未生成文件"
  fi
else
  kubellm::log::info "跳过 CRD 生成..."
fi

# 8. 生成 Protobuf 代码
kubellm::log::info "8. 生成 Protobuf 代码..."
if [[ "${ENABLE_PROTOBUF}" == "true" ]]; then
  # 检查所需工具
  if ! command -v protoc &>/dev/null && ! [[ -x "${PROJECT_ROOT}/bin/protoc" ]]; then
    kubellm::log::warning "未找到 protoc 命令，跳过 Protobuf 生成"
  else
    # 使用 code-generator 工具生成 Protobuf
    kube::codegen::gen_protobuf
    
    # 验证生成结果
    pb_files=$(find "${PROJECT_ROOT}/pkg/apis" -name "*.pb.go" -type f 2>/dev/null)
    if [[ -n "${pb_files}" ]]; then
      pb_count=$(echo "${pb_files}" | wc -l)
      kubellm::log::info "✓ Protobuf 生成成功 (${pb_count} 个文件)"
    else
      kubellm::log::warning "❌ 未找到生成的 Protobuf 文件"
    fi
  fi
else
  kubellm::log::info "跳过 Protobuf 生成..."
fi

kubellm::log::info "代码生成完成!"