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

# 引入初始化脚本
PROJECT_ROOT=$(dirname "${BASH_SOURCE[0]}")/../..
source "${PROJECT_ROOT}/hack/lib/init.sh"

# =================================================================
# Kubernetes 风格的代码生成工具集
# 基于原生 k8s 代码生成器，扩展增强的功能
# =================================================================

# 创建从 kube:: 到 kubellm:: 的日志函数别名
# 这是为了兼容k8s原生代码生成器中的日志调用
kube::log::status() {
  kubellm::log::info "$@"
}

kube::log::info() {
  kubellm::log::info "$@"
}

kube::log::error() {
  kubellm::log::error "$@"
}

kube::log::warning() {
  kubellm::log::warn "$@"
}

kube::log::fatal() {
  kubellm::log::fatal "$@"
}

# 设置代码生成工具路径变量
# 使用which命令获取工具的绝对路径
# 如果工具不在PATH中，则尝试从GOPATH/bin获取
GOBIN=${GOBIN:-$(go env GOPATH)/bin}

# 定义工具路径
DEEPCOPY_GEN=$(command -v deepcopy-gen 2>/dev/null || echo "${GOBIN}/deepcopy-gen")
DEFAULTER_GEN=$(command -v defaulter-gen 2>/dev/null || echo "${GOBIN}/defaulter-gen") 
CONVERSION_GEN=$(command -v conversion-gen 2>/dev/null || echo "${GOBIN}/conversion-gen")
CLIENT_GEN=$(command -v client-gen 2>/dev/null || echo "${GOBIN}/client-gen")
LISTER_GEN=$(command -v lister-gen 2>/dev/null || echo "${GOBIN}/lister-gen")
INFORMER_GEN=$(command -v informer-gen 2>/dev/null || echo "${GOBIN}/informer-gen")
OPENAPI_GEN=$(command -v openapi-gen 2>/dev/null || echo "${GOBIN}/openapi-gen")
CONTROLLER_GEN=$(command -v controller-gen 2>/dev/null || echo "${GOBIN}/controller-gen")
REGISTER_GEN=$(command -v register-gen 2>/dev/null || echo "${GOBIN}/register-gen")
APPLYCONFIGURATION_GEN=$(command -v applyconfiguration-gen 2>/dev/null || echo "${GOBIN}/applyconfiguration-gen")

# 设置详细级别
OUT_PUT_LEVEL=${OUT_PUT_LEVEL:-3}

# 定义通用输出目录
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/pkg}"
CLIENT_OUTPUT_DIR="${CLIENT_ROOT:-${OUTPUT_DIR}/client}"

# 检查必要的工具是否可用
check_codegen_tools() {
  local missing_tools=()
  
  [[ ! -x "${DEEPCOPY_GEN}" ]] && missing_tools+=("deepcopy-gen")
  [[ ! -x "${REGISTER_GEN}" ]] && missing_tools+=("register-gen")
  [[ ! -x "${DEFAULTER_GEN}" ]] && missing_tools+=("defaulter-gen")
  [[ ! -x "${CONVERSION_GEN}" ]] && missing_tools+=("conversion-gen")
  [[ ! -x "${CLIENT_GEN}" ]] && missing_tools+=("client-gen")
  [[ ! -x "${LISTER_GEN}" ]] && missing_tools+=("lister-gen")
  [[ ! -x "${INFORMER_GEN}" ]] && missing_tools+=("informer-gen")
  [[ ! -x "${OPENAPI_GEN}" ]] && missing_tools+=("openapi-gen")
  [[ ! -x "${CONTROLLER_GEN}" ]] && missing_tools+=("controller-gen")
  [[ ! -x "${APPLYCONFIGURATION_GEN}" ]] && missing_tools+=("applyconfiguration-gen")
  
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    kube::log::error "缺少必要的代码生成工具: ${missing_tools[*]}"
    kube::log::error "请先运行 hack/codegen/install-tools.sh 安装这些工具"
                    return 1
                fi

  return 0
}

# 检查工具是否可用
check_codegen_tools || exit 1

# 获取API包的辅助函数，使用全局变量返回结果
kube::codegen::find_api_packages() {
  # 声明为全局变量
  FOUND_API_PKGS=()
  
  # 如果没有指定 API_GROUPS，则自动扫描
  if [[ -z "${API_GROUPS}" ]]; then
    # 遍历 API_ROOT 下的所有目录
    for group_dir in $(find "${API_ROOT}" -maxdepth 1 -type d | sort); do
      # 跳过 API_ROOT 本身
      if [[ "${group_dir}" == "${API_ROOT}" ]]; then
        continue
      fi
      
      local group=$(basename "${group_dir}")
      # 跳过隐藏目录
      if [[ "${group}" == .* ]]; then
        continue
      fi
      
      local group_pkg="${APIS_PKG}/${group}"
      
      # 检查版本子目录
      for version_dir in $(find "${group_dir}" -maxdepth 1 -type d | sort); do
        if [[ "${version_dir}" == "${group_dir}" ]]; then
          continue
        fi
        
        local version=$(basename "${version_dir}")
        # 跳过隐藏目录
        if [[ "${version}" == .* ]]; then
          continue
        fi

        # 跳过名为 install 的目录
        if [[ "${version}" == "install" ]]; then
          kube::log::info "find_api_packages: 跳过 install 目录: ${version_dir}"
          continue
        fi
        
        # 确保是有效的版本名 (例如 v1, v1alpha1)
        if ! [[ "${version}" =~ ^v[0-9]+((alpha|beta)[0-9]+)?$ ]]; then
            kube::log::debug "find_api_packages: 跳过非标准版本名目录 '${version}' in ${group_dir}"
            continue
        fi

        local input_pkg="${group_pkg}/${version}"
        FOUND_API_PKGS+=("${input_pkg}")
        kube::log::status "find_api_packages: 找到外部API包: ${input_pkg}"
      done
    done
  else
    # 使用用户指定的API组
    IFS=',' read -ra groups_spec <<< "${API_GROUPS}"
    for group_spec in "${groups_spec[@]}"; do
      IFS='/' read -ra parts <<< "${group_spec}"
      if [[ ${#parts[@]} -lt 2 ]]; then
        kube::log::error "API组格式错误: ${group_spec}，应为 group/version"
        continue
      fi
      
      local group_name_spec="${parts[0]}"
      local version_spec="${parts[1]}"

      # 跳过名为 install 的版本
      if [[ "${version_spec}" == "install" ]]; then
        kube::log::warning "find_api_packages: 跳过指定的 install API组: ${group_spec}"
        continue
      fi

      # 确保是有效的版本名
      if ! [[ "${version_spec}" =~ ^v[0-9]+((alpha|beta)[0-9]+)?$ ]]; then
          kube::log::warning "find_api_packages: 跳过指定的非标准版本API组: ${group_spec}"
          continue
      fi

      local input_pkg="${APIS_PKG}/${group_name_spec}/${version_spec}"
      FOUND_API_PKGS+=("${input_pkg}")
      kube::log::status "find_api_packages: 找到指定的外部API包: ${input_pkg}"
    done
  fi
}

# 新增：获取内部API包的辅助函数
# 内部API包通常直接在 group 目录下，不带版本号的子目录，但其下直接包含 Go 源文件
# 例如：pkg/apis/iam.kubellm.io/types.go (包路径: ${APIS_PKG}/iam.kubellm.io)
kube::codegen::find_internal_api_packages() {
  # 声明为全局变量
  FOUND_INTERNAL_API_PKGS=()
  
  kube::log::status "开始扫描内部API包..."
  # 扫描 API_ROOT (e.g., pkg/apis) 下的每个 group 目录
  for group_dir in $(find "${API_ROOT}" -maxdepth 1 -type d | sort); do
    if [[ "${group_dir}" == "${API_ROOT}" ]]; then
      continue # 跳过 API_ROOT 本身
    fi
    
    local group_name=$(basename "${group_dir}")
    if [[ "${group_name}" == .* ]]; then
      kube::log::debug "find_internal_api_packages: 跳过隐藏目录: ${group_dir}"
      continue # 跳过隐藏目录
    fi

    # 条件1: 当前 group 目录必须直接包含 .go 文件，表明它自身是一个Go包
    if ! find "${group_dir}" -maxdepth 1 -name '*.go' -type f -print -quit 2>/dev/null; then
      kube::log::debug "find_internal_api_packages: 目录 ${group_dir} 不直接包含Go文件，因此不是内部API包的根目录，跳过。"
      continue
    fi

    # 如果满足以上所有条件，则认为它是一个内部API包
    local internal_pkg_path="${APIS_PKG}/${group_name}"
    
    FOUND_INTERNAL_API_PKGS+=("${internal_pkg_path}")
    kube::log::status "find_internal_api_packages: 找到潜在的内部API包: ${internal_pkg_path}"
  done

  if [[ ${#FOUND_INTERNAL_API_PKGS[@]} -eq 0 ]]; then
    kube::log::info "find_internal_api_packages: 未扫描到符合条件的内部API包。"
  else
    kube::log::info "find_internal_api_packages: 完成扫描，共找到 ${#FOUND_INTERNAL_API_PKGS[@]} 个潜在的内部API包。"
    # 可以进行去重，尽管 find 的结果本身可能已经是唯一的目录
    local unique_internal_pkgs=()
    declare -A seen_internal_pkgs
    for pkg in "${FOUND_INTERNAL_API_PKGS[@]}"; do
        if [[ -z "${seen_internal_pkgs[$pkg]+_}" ]]; then
            unique_internal_pkgs+=("$pkg")
            seen_internal_pkgs[$pkg]=1
        fi
    done
    FOUND_INTERNAL_API_PKGS=("${unique_internal_pkgs[@]}")
    kube::log::info "find_internal_api_packages: 去重后，确认 ${#FOUND_INTERNAL_API_PKGS[@]} 个内部API包: ${FOUND_INTERNAL_API_PKGS[*]}"
  fi
}

# 仅生成 DeepCopy 代码 (针对外部版本)
kube::codegen::gen_deepcopy() {
  kube::log::status "生成 DeepCopy 代码 (针对外部版本)..."
  
  # 检查是否启用
  if [[ "${ENABLE_DEEPCOPY}" != "true" ]]; then
    kube::log::status "DeepCopy生成已禁用，跳过"
    return 0
  fi

  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取外部API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到外部API包，跳过DeepCopy代码生成"
    return 0
  fi
  
  kube::log::info "将为以下外部包生成DeepCopy: ${FOUND_API_PKGS[*]}"

  local args=()
  args+=("--output-file=zz_generated.deepcopy.go")
  args+=("--go-header-file=${BOILERPLATE}")
  
  kube::log::info "执行: ${DEEPCOPY_GEN} ${args[*]} ${FOUND_API_PKGS[*]}"
  ${DEEPCOPY_GEN} "${args[@]}" "${FOUND_API_PKGS[@]}"
  
  kube::log::status "外部版本 DeepCopy 代码生成完成"
}

# 仅生成 Register 代码 (针对外部版本)
kube::codegen::gen_register() {
  kube::log::status "生成 Register 代码 (针对外部版本)..."
  
  # 检查是否启用
  if [[ "${ENABLE_REGISTER}" != "true" ]]; then
    kube::log::status "Register生成已禁用，跳过"
    return 0
  fi
  
  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取外部API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到外部API包，跳过Register代码生成"
    return 0
  fi

  kube::log::info "将为以下外部包生成Register: ${FOUND_API_PKGS[*]}"
  
  local args=()
  args+=("--output-file=zz_generated.register.go")
  args+=("--go-header-file=${BOILERPLATE}")
  
  kube::log::info "执行: ${REGISTER_GEN} ${args[*]} ${FOUND_API_PKGS[*]}"
  ${REGISTER_GEN} "${args[@]}" "${FOUND_API_PKGS[@]}"
  
  kube::log::status "外部版本 Register 代码生成完成"
}

# 新增：为内部API版本生成 DeepCopy 和 Register 代码
# 新增：为内部API版本生成 DeepCopy 和 Register 代码
kube::codegen::generate_internal_apis_deepcopy_and_register() {
  kube::log::status "开始为内部API版本生成 DeepCopy 和 Register 代码..."

  # 1. 查找内部API包
  # 清空以确保从新的扫描开始
  FOUND_INTERNAL_API_PKGS=()
  kube::codegen::find_internal_api_packages

  if [[ ${#FOUND_INTERNAL_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到内部API包，跳过内部版本的 DeepCopy 和 Register 代码生成。"
    return 0
  fi

  kube::log::info "将为以下内部API包生成 DeepCopy 和 Register: ${FOUND_INTERNAL_API_PKGS[*]}"

  # 2. 生成 DeepCopy 代码
  if [[ "${ENABLE_DEEPCOPY}" == "true" ]]; then
    kube::log::status "为内部API包生成 DeepCopy 代码..."
    local deepcopy_args=()
    deepcopy_args+=("--output-file=zz_generated.deepcopy.go")
    deepcopy_args+=("--go-header-file=${BOILERPLATE}")
    
    kube::log::info "执行 DeepCopy (内部): ${DEEPCOPY_GEN} ${deepcopy_args[*]} ${FOUND_INTERNAL_API_PKGS[*]}"
    if ! ${DEEPCOPY_GEN} "${deepcopy_args[@]}" "${FOUND_INTERNAL_API_PKGS[@]}"; then
        kube::log::error "内部API版本 DeepCopy 代码生成失败。"
        # 根据需要决定是否在此处返回错误
    else
        kube::log::status "内部API版本 DeepCopy 代码生成完成。"
    fi
  else
    kube::log::info "内部API版本 DeepCopy 生成已禁用 (ENABLE_DEEPCOPY=${ENABLE_DEEPCOPY})。"
  fi

  # 3. 生成 Register 代码
  if [[ "${ENABLE_REGISTER}" == "true" ]]; then
    kube::log::status "为内部API包生成 Register 代码..."
    local register_args=()
    register_args+=("--output-file=zz_generated.register.go")
    register_args+=("--go-header-file=${BOILERPLATE}")

    kube::log::info "执行 Register (内部): ${REGISTER_GEN} ${register_args[*]} ${FOUND_INTERNAL_API_PKGS[*]}"
    if ${REGISTER_GEN} "${register_args[@]}" "${FOUND_INTERNAL_API_PKGS[@]}"; then
        kube::log::status "内部API版本 Register 代码生成完成。"
        
        # 后处理：修正内部版本的注册文件
        kube::log::status "为内部API的 register 文件进行后处理..."
        for internal_pkg_go_path in "${FOUND_INTERNAL_API_PKGS[@]}"; do
            local relative_pkg_dir="${internal_pkg_go_path#${ROOT_PACKAGE}/}"
            local register_file_path="${PROJECT_ROOT}/${relative_pkg_dir}/zz_generated.register.go"

            if [[ -f "${register_file_path}" ]]; then
                local group_name_from_dir=$(basename "${relative_pkg_dir}")
                local escaped_group_name_for_sed=$(echo "${group_name_from_dir}" | sed 's/\./\\./g')

                kubellm::log::info "  处理文件: ${register_file_path}"
                
                local tmp_file="${register_file_path}.tmp"
                
                # 一次性完成所有修改：
                # 1. 将版本替换为 runtime.APIVersionInternal
                # 2. 移除 v1.AddToGroupVersion 调用
                sed -e "s/\(var GroupVersion = v1\.GroupVersion{Group: GroupName, Version: \)\""${escaped_group_name_for_sed}\""/\1runtime.APIVersionInternal/" \
                    -e "s/\(var SchemeGroupVersion = schema\.GroupVersion{Group: GroupName, Version: \)\""${escaped_group_name_for_sed}\""/\1runtime.APIVersionInternal/" \
                    -e '/v1\.AddToGroupVersion(scheme, SchemeGroupVersion)/d' \
                    "${register_file_path}" > "${tmp_file}"

                if [[ $? -eq 0 && -s "${tmp_file}" ]]; then
                    # 验证修改是否成功
                    local version_updated=$(grep -c "Version: runtime.APIVersionInternal" "${tmp_file}")
                    local add_call_removed=$(grep -c "v1.AddToGroupVersion(scheme, SchemeGroupVersion)" "${tmp_file}")
                    
                    if [[ $version_updated -ge 2 && $add_call_removed -eq 0 ]]; then
                        mv "${tmp_file}" "${register_file_path}"
                        kubellm::log::info "    ✅ 内部版本注册文件修复成功"
                        kubellm::log::info "      - 版本已更新为 runtime.APIVersionInternal"
                        kubellm::log::info "      - 移除了 v1.AddToGroupVersion 调用"
                    else
                        kubellm::log::error "    ❌ 内部版本修复失败："
                        kubellm::log::error "      - 版本更新: $version_updated/2 (应为2)"
                        kubellm::log::error "      - AddToGroupVersion 残留: $add_call_removed (应为0)"
                        rm -f "${tmp_file}"
                    fi
                else
                    kubellm::log::error "    ❌ sed 处理失败或生成空文件"
                    [[ -f "${tmp_file}" ]] && rm -f "${tmp_file}"
                fi
            else
                kubellm::log::warn "  Register 文件未找到: ${register_file_path}"
            fi
        done
    else
        kube::log::error "内部API版本 Register 代码生成失败。"
    fi
  else
    kube::log::info "内部API版本 Register 生成已禁用 (ENABLE_REGISTER=${ENABLE_REGISTER})。"
  fi
  
  kube::log::status "内部API版本的 DeepCopy 和 Register 代码生成流程结束。"
}

# 仅生成 Defaulter 代码 (针对外部版本)
kube::codegen::gen_defaulter() {
  kube::log::status "生成 Defaulter 代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_DEFAULTER}" != "true" ]]; then
    kube::log::status "Defaulter生成已禁用，跳过"
    return 0
  fi
  
  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过Defaulter代码生成"
    return 0
  fi
  
  # 构建参数
  local args=()
  args+=("--output-file=zz_generated.defaults.go")
  args+=("--go-header-file=${BOILERPLATE}")
  
  # 修复：将包列表作为独立的参数传递，而不是用逗号连接
  kube::log::info "执行: ${DEFAULTER_GEN} ${args[*]} ${FOUND_API_PKGS[*]}"
  ${DEFAULTER_GEN} "${args[@]}" "${FOUND_API_PKGS[@]}"
  
  kube::log::status "Defaulter代码生成完成"
}

# 仅生成 Conversion 代码
kube::codegen::gen_conversion() {
  kube::log::status "生成 Conversion 代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_CONVERSION}" != "true" ]]; then
    kube::log::status "Conversion生成已禁用，跳过"
    return 0
  fi
  
  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过Conversion代码生成"
    return 0
  fi
  
  # 构建参数
  local args=()
  args+=("--output-file=zz_generated.conversion.go")
  args+=("--go-header-file=${BOILERPLATE}")
  
  # 修复：将包列表作为独立的参数传递，而不是用逗号连接
  kube::log::info "执行: ${CONVERSION_GEN} ${args[*]} ${FOUND_API_PKGS[*]}"
  ${CONVERSION_GEN} "${args[@]}" "${FOUND_API_PKGS[@]}"
  
  kube::log::status "Conversion代码生成完成"
}

# 生成验证代码
kube::codegen::gen_validation() {
  kube::log::status "生成验证代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_VALIDATION}" != "true" ]]; then
    kube::log::status "验证代码生成已禁用，跳过"
    return 0
  fi
  
  # 检查validation-gen工具
  VALIDATION_GEN=$(command -v validation-gen 2>/dev/null || echo "${GOBIN}/validation-gen")
  if [[ ! -x "${VALIDATION_GEN}" ]]; then
    kube::log::error "validation-gen 命令未找到"
    kube::log::error "请先运行: go install k8s.io/code-generator/cmd/validation-gen@latest"
                    return 1
                fi

  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过验证代码生成"
    return 0
  fi
  
  # 构建参数
  local args=()
  args+=("--output-file=zz_generated.validation.go")
  args+=("--go-header-file=${BOILERPLATE}")
  
  # 修改只读包列表，添加更多依赖包
  VALIDATION_READONLY_PKGS="k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/runtime,k8s.io/apimachinery/pkg/util/intstr,k8s.io/apimachinery/pkg/types,k8s.io/apimachinery/pkg/runtime/schema,k8s.io/apimachinery/pkg/fields,k8s.io/apimachinery/pkg/labels,k8s.io/apimachinery/pkg/selection,k8s.io/apimachinery/pkg/util/validation/field,k8s.io/apimachinery/pkg/api/operation,k8s.io/apimachinery/pkg/api/validate,k8s.io/apimachinery/pkg/api/safe,time"  # 设置额外参数
  VALIDATION_EXTRA_ARGS="-v=2"

  if [[ -n "${VALIDATION_READONLY_PKGS}" ]]; then
    IFS=',' read -ra readonly_pkgs <<< "${VALIDATION_READONLY_PKGS}"
    for pkg in "${readonly_pkgs[@]}"; do
      args+=("--readonly-pkg=${pkg}")
    done
  fi
  
  # 添加自定义参数（如果已配置）
  if [[ -n "${VALIDATION_EXTRA_ARGS}" ]]; then
    IFS=',' read -ra extra_args <<< "${VALIDATION_EXTRA_ARGS}"
    for arg in "${extra_args[@]}"; do
      args+=("${arg}")
    done
  fi
  
  # 修复：将包列表作为独立的参数传递，而不是用逗号连接
  kube::log::info "执行: ${VALIDATION_GEN} ${args[*]} ${FOUND_API_PKGS[*]}"
  ${VALIDATION_GEN} "${args[@]}" "${FOUND_API_PKGS[@]}"
  
  kube::log::status "验证代码生成完成"
}

# 生成 ApplyConfiguration 代码
kube::codegen::gen_applyconfiguration() {
  kube::log::status "生成 ApplyConfiguration 代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_APPLYCONFIGURATION}" != "true" ]]; then
    kube::log::status "ApplyConfiguration生成已禁用，跳过"
    return 0
  fi
  
  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过ApplyConfiguration代码生成"
    return 0
  fi
  
  # 确保输出目录存在
  mkdir -p "${CLIENT_ROOT}/applyconfiguration"
  
  # 构建参数
  local args=()
  args+=("--output-pkg=${CLIENT_PKG}/applyconfiguration")
  args+=("--output-dir=${CLIENT_ROOT}/applyconfiguration")
  args+=("--go-header-file=${BOILERPLATE}")
  
  # 修复：将包列表作为独立的参数传递，而不是用逗号连接
  kube::log::info "执行: ${APPLYCONFIGURATION_GEN} ${args[*]} ${FOUND_API_PKGS[*]} -v=${OUT_PUT_LEVEL}"
  ${APPLYCONFIGURATION_GEN} "${args[@]}" "${FOUND_API_PKGS[@]}" -v=${OUT_PUT_LEVEL}
  
  kube::log::status "ApplyConfiguration代码生成完成"
}

# 仅生成 Clientset 代码
kube::codegen::gen_clientset() {
  kube::log::status "生成 Clientset 代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_CLIENTSET}" != "true" ]]; then
    kube::log::status "Clientset生成已禁用，跳过"
    return 0
  fi

  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过Clientset代码生成"
    return 0
  fi
  
  # 检查目录是否存在
  mkdir -p "${CLIENT_ROOT}/clientset"
  
  # 从API包提取组和版本信息，构建输入参数
  local group_versions=()
  local all_groups=()
  
  for input_pkg in "${FOUND_API_PKGS[@]}"; do
    # 从包路径提取组和版本信息
    # 例如：github.com/kubellm-io/kubellm/pkg/apis/iam/v1alpha1
    IFS='/' read -ra parts <<< "${input_pkg}"
    local group_idx=$((${#parts[@]} - 2))
    local version_idx=$((${#parts[@]} - 1))
    local group="${parts[group_idx]}"
    local version="${parts[version_idx]}"
    
    # 检查该组是否已经添加
    local group_found=false
    for i in "${!group_versions[@]}"; do
      IFS=':' read -ra gv_parts <<< "${group_versions[i]}"
      if [[ "${gv_parts[0]}" == "${group}" ]]; then
        # 添加版本到现有组
        group_versions[i]="${group_versions[i]},${version}"
        group_found=true
        break
      fi
    done
    
    # 如果组不存在，添加新组
    if [[ "${group_found}" == "false" ]]; then
      group_versions+=("${group}:${version}")
      all_groups+=("${group}")
    fi
  done
  
  # 构建输入参数
  local inputs=()
  for group in "${all_groups[@]}"; do
    # 检查是否有版本目录
    for version_dir in $(find "${API_ROOT}/${group}" -maxdepth 1 -type d | sort); do
      if [[ "${version_dir}" == "${API_ROOT}/${group}" ]]; then
        continue
      fi
      local version=$(basename "${version_dir}")
      if [[ "${version}" == .* ]]; then
        continue
      fi
      # *** 新增：在这里也要跳过 install 目录 ***
      if [[ "${version}" == "install" ]]; then
        kube::log::info "(Clientset) 跳过 install 目录: ${version_dir}"
        continue
      fi
      inputs+=("./pkg/apis/${group}/${version}")
    done
  done
  # 构建参数
  local client_args=()
  client_args+=("--go-header-file=${BOILERPLATE}")
  client_args+=("--input-base=${ROOT_PACKAGE}")
  client_args+=("--clientset-name=versioned")
  client_args+=("--apply-configuration-package=${CLIENT_PKG}/applyconfiguration")
  client_args+=("--output-pkg=${CLIENT_PKG}/clientset")
  client_args+=("--output-dir=${CLIENT_OUTPUT_DIR}/clientset")
  
  # 添加输入参数
  for input in "${inputs[@]}"; do
    client_args+=("--input=${input}")
  done
  
  kube::log::info "生成 Clientset: ${all_groups[*]}"
  kube::log::info "执行: ${CLIENT_GEN} ${client_args[*]}"
  "${CLIENT_GEN}" "${client_args[@]}"
  
  kube::log::status "Clientset代码生成完成"
}

# 仅生成 Lister 代码
kube::codegen::gen_lister() {
  kube::log::status "生成 Lister 代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_LISTER}" != "true" ]]; then
    kube::log::status "Lister生成已禁用，跳过"
    return 0
  fi

  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过Lister代码生成"
    return 0
  fi
  
  # 确保Lister的根物理输出目录存在 (例如 pkg/generated/listers)
  # lister-gen会在此目录下按 group/version 创建子目录
  mkdir -p "${CLIENT_OUTPUT_DIR}/listers"
  
  # 从API包提取组和版本信息
  for input_pkg in "${FOUND_API_PKGS[@]}"; do
    # 从包路径提取组和版本信息
    # 例如：github.com/kubellm-io/kubellm/pkg/apis/iam.kubellm.io/v1alpha1
    IFS='/' read -ra parts <<< "${input_pkg}"
    local group_idx=$((${#parts[@]} - 2))
    local version_idx=$((${#parts[@]} - 1))
    local group="${parts[group_idx]}"
    local version="${parts[version_idx]}"
    
    # 构建参数
    local lister_args=()
    lister_args+=("--go-header-file=${BOILERPLATE}")
    # output-pkg 指向Lister的根包名，例如 "github.com/kubellm-io/kubellm/pkg/generated/listers"
    # lister-gen 会自动在此包下创建 group/version 结构
    lister_args+=("--output-pkg=${CLIENT_PKG}/listers")
    # output-dir 指向Lister的根目录，例如 "PROJECT_ROOT/pkg/generated/listers"
    # lister-gen 会自动在此目录下创建 group/version 结构
    lister_args+=("--output-dir=${CLIENT_OUTPUT_DIR}/listers")
    
    kube::log::info "为API包 ${input_pkg} 生成 Lister (预期输出到 ${CLIENT_PKG}/listers/${group}/${version})"
    kube::log::info "执行: ${LISTER_GEN} ${lister_args[*]} ${input_pkg}"
    ${LISTER_GEN} "${lister_args[@]}" "${input_pkg}"
  done
  
  kube::log::status "Lister代码生成完成"
}

# 仅生成 Informer 代码
kube::codegen::gen_informer() {
  kube::log::status "生成 Informer 代码..."
  
  # 检查是否启用
  if [[ "${ENABLE_INFORMER}" != "true" ]]; then
    kube::log::status "Informer生成已禁用，跳过"
    return 0
  fi
  
  # 检查 clientset 和 lister 目录是否存在
  if [[ ! -d "${CLIENT_OUTPUT_DIR}/clientset" ]]; then
    kube::log::error "生成 Informer 前需要先生成 Clientset，请先运行 './hack/codegen/kube_codegen.sh clientset'"
        return 1
    fi
  
  # 确保 Lister 代码已正确生成 (Lister的根目录应该存在)
  if [[ ! -d "${CLIENT_OUTPUT_DIR}/listers" ]]; then
    kube::log::error "生成 Informer 前需要先生成 Lister，请先运行 './hack/codegen/kube_codegen.sh lister'"
        return 1
    fi

  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过Informer代码生成"
    return 0
  fi
  
  # 确保Informer的根输出目录存在
  # informer-gen会在此目录下按 group/version 创建子目录
  mkdir -p "${CLIENT_OUTPUT_DIR}/informers"
  
  # 从API包提取组和版本信息
  for input_pkg in "${FOUND_API_PKGS[@]}"; do
    # 从包路径提取组和版本信息
    # 例如：github.com/kubellm-io/kubellm/pkg/apis/iam.kubellm.io/v1alpha1
    IFS='/' read -ra parts <<< "${input_pkg}"
    local group_idx=$((${#parts[@]} - 2))
    local version_idx=$((${#parts[@]} - 1))
    local group="${parts[group_idx]}"
    local version="${parts[version_idx]}"
    
    # 构建参数
    local informer_args=()
    informer_args+=("--go-header-file=${BOILERPLATE}")
    informer_args+=("--versioned-clientset-package=${CLIENT_PKG}/clientset/versioned")
    # listers-package 需要指向特定 group/version 的 lister 包路径
    # 假设 lister 已按 group/version 正确生成在 ${CLIENT_PKG}/listers/${group}/${version}
    informer_args+=("--listers-package=${CLIENT_PKG}/listers")
    # output-pkg 指向Informer的根包名
    informer_args+=("--output-pkg=${CLIENT_PKG}/informers")
    # output-dir 指向Informer的根目录
    informer_args+=("--output-dir=${CLIENT_OUTPUT_DIR}/informers")
    
    kube::log::info "为API包 ${input_pkg} 生成 Informer (预期输出到 ${CLIENT_PKG}/informers/${group}/${version})"
    kube::log::info "执行: ${INFORMER_GEN} ${informer_args[*]} ${input_pkg}"
    ${INFORMER_GEN} "${informer_args[@]}" "${input_pkg}"
  done
  
  kube::log::status "Informer代码生成完成"
}

# 生成 OpenAPI 规范代码
kube::codegen::gen_openapi() {
  # 检查功能开关
  if [[ "${ENABLE_OPENAPI}" != "true" ]]; then
    kube::log::status "OpenAPI生成已被禁用，跳过"
    return 0
  fi

  kube::log::status "生成OpenAPI代码..."
  
  # 1. 获取本地 API 包
  FOUND_API_PKGS=()
  kube::codegen::find_api_packages
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到本地API包，无法生成OpenAPI"
    return 0
  fi

  # 2. 定义需要包含的标准 Kubernetes 包
  local K8S_STANDARD_PKGS=(
    "k8s.io/api/rbac/v1"
    "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/version"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/api/resource"
    "k8s.io/api/core/v1"
    "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
    "k8s.io/api/admissionregistration/v1"
    "k8s.io/api/networking/v1"
    "k8s.io/metrics/pkg/apis/custom_metrics"
    "k8s.io/metrics/pkg/apis/custom_metrics/v1beta1"
    "k8s.io/metrics/pkg/apis/custom_metrics/v1beta2"
    "k8s.io/metrics/pkg/apis/external_metrics"
    "k8s.io/metrics/pkg/apis/external_metrics/v1beta1"
    "k8s.io/metrics/pkg/apis/metrics"
    "k8s.io/metrics/pkg/apis/metrics/v1beta1"
    "k8s.io/api/autoscaling/v2"
    # 可以根据需要添加更多标准包
  )
  
  # 3. 合并本地和标准包列表
  local all_pkgs=("${FOUND_API_PKGS[@]}" "${K8S_STANDARD_PKGS[@]}")

  # 5. 准备输出目录和文件名
  local openapi_output_dir="${CLIENT_OUTPUT_DIR}/openapi"
  mkdir -p "${openapi_output_dir}"
  local output_file_name="zz_generated.openapi.go" 

  # 6. 构建 openapi-gen 参数
  local args=()
  args+=("--output-pkg" "${CLIENT_PKG}/openapi") 
  args+=("--output-file" "${output_file_name}") 
  args+=("--go-header-file" "${BOILERPLATE}")
  args+=("--output-dir" "${openapi_output_dir}") # 显式指定输出目录
  args+=("-v=${OUT_PUT_LEVEL}")
  local report_file="${PROJECT_ROOT}/hack/.openapi-report.txt"
  args+=("--report-filename" "${report_file}")
  rm -f "${report_file}" # 清理旧报告
  
  # 7. 执行命令，将包列表作为位置参数附加在末尾
  kube::log::info "执行: ${OPENAPI_GEN} ${args[*]} ${all_pkgs[*]}"
  ${OPENAPI_GEN} "${args[@]}" "${all_pkgs[@]}"
  
  # 8. 验证生成结果
  local expected_output_file="${openapi_output_dir}/${output_file_name}"
  if [[ -f "${expected_output_file}" ]]; then
    kube::log::status "OpenAPI代码生成成功: ${expected_output_file}"
    if [[ -s "${report_file}" ]]; then
        kube::log::warning "OpenAPI 生成报告中有内容 (可能有冲突或警告): ${report_file}"
    fi
  else
    kube::log::error "OpenAPI代码生成失败，输出文件未找到: ${expected_output_file}"
    if [[ -f "${report_file}" ]]; then
        kube::log::error "OpenAPI 生成报告内容:"
        cat "${report_file}"
    fi
    return 1
  fi
}

# 生成 CRD 清单文件
kube::codegen::gen_crd() {
  # 检查功能开关
  if [[ "${ENABLE_CRD}" != "true" ]]; then
    kube::log::status "CRD生成已被禁用，跳过"
    return 0
  fi

  kube::log::status "生成CRD清单..."
  
  # 确保输出目录存在
  mkdir -p "${CRD_OUTPUT_DIR}"

  # 先清空全局变量
  FOUND_API_PKGS=()
  
  # 获取API包
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过CRD生成"
    return 0
  fi

  # 确保 controller-gen 可用
  if [[ ! -x "${CONTROLLER_GEN}" ]]; then
    kube::log::error "controller-gen 命令未找到，请先安装"
    kube::log::error "运行: go install sigs.k8s.io/controller-tools/cmd/controller-gen@latest"
    return 1
  fi

  # 获取 controller-gen 版本
  local controller_gen_version=$(${CONTROLLER_GEN} --version 2>&1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
  kube::log::info "使用 controller-gen 版本: ${controller_gen_version}"

  # 设置 CRD 生成选项，根据版本不同可能需要调整
  # 注意：新版 controller-gen 支持更多选项
  local CRD_GEN_OPTIONS="crd:generateEmbeddedObjectMeta=true,allowDangerousTypes=true,maxDescLen=0,crdVersions=v1"
  
  # 检测是否使用自定义的 CRD 选项
  if [[ -n "${CRD_GEN_OPTIONS_OVERRIDE:-}" ]]; then
    kube::log::info "使用自定义CRD选项: ${CRD_GEN_OPTIONS_OVERRIDE}"
    CRD_GEN_OPTIONS="${CRD_GEN_OPTIONS_OVERRIDE}"
  fi
  
  # 构建输入路径参数，为每个API包添加/...后缀以包含子目录
  # local paths_args=()
  # for pkg in "${FOUND_API_PKGS[@]}"; do
  #   paths_args+=("${pkg}/...")
  # done
  local paths_args=()
  for pkg in "${FOUND_API_PKGS[@]}"; do
    paths_args+=("paths=${pkg}/...")
  done

  # 使用数组形式传递路径参数，避免字符串转义问题
  # local paths_arg=$(IFS=, ; echo "paths=${paths_args[*]}")
  local output_arg="output:crd:artifacts:config=${CRD_OUTPUT_DIR}"

  # 执行 controller-gen 命令
  # kube::log::info "执行: ${CONTROLLER_GEN} ${CRD_GEN_OPTIONS} ${paths_arg} ${output_arg}"
  # "${CONTROLLER_GEN}" ${CRD_GEN_OPTIONS} ${paths_arg} ${output_arg}
  kube::log::info "执行: ${CONTROLLER_GEN} ${CRD_GEN_OPTIONS} ${paths_args[*]} ${output_arg}"
  "${CONTROLLER_GEN}" ${CRD_GEN_OPTIONS} ${paths_args[@]} ${output_arg}
  
  # 验证生成结果
  local crd_count=$(find "${CRD_OUTPUT_DIR}" -name "*.yaml" | wc -l)
  if [[ ${crd_count} -gt 0 ]]; then
    kube::log::status "CRD清单生成成功: 共 ${crd_count} 个文件"
    # 列出生成的CRD文件
    find "${CRD_OUTPUT_DIR}" -name "*.yaml" -exec basename {} \; | while read -r crd_file; do
      kube::log::info "✓ 生成: ${crd_file}"
    done
  else
    kube::log::error "CRD清单生成可能失败，未找到yaml文件"
    return 1
  fi
}

# 生成 Protobuf 代码
kube::codegen::gen_protobuf() {
  # 检查功能开关
  if [[ "${ENABLE_PROTOBUF}" != "true" ]]; then
    kube::log::status "Protobuf生成已被禁用，跳过"
    return 0
  fi

  kube::log::status "生成Protobuf代码..."
  
  # 检查go-to-protobuf工具
  GO_TO_PROTOBUF=$(command -v go-to-protobuf 2>/dev/null || echo "${GOBIN}/go-to-protobuf")
  if [[ ! -x "${GO_TO_PROTOBUF}" ]]; then
    kube::log::error "go-to-protobuf 命令未找到，请安装此工具"
    kube::log::error "运行: go install k8s.io/code-generator/cmd/go-to-protobuf@${CODE_GENERATOR_VERSION:-latest}"
                    return 1
                fi
  
  # 检查protoc编译器，优先检查本地bin目录
  LOCAL_PROTOC="${SCRIPT_ROOT}/bin/protoc"
  if [[ -x "${LOCAL_PROTOC}" ]]; then
    PROTOC="${LOCAL_PROTOC}"
    kube::log::info "使用本地protoc: ${PROTOC}"
    # 确保protoc在PATH中可用
    export PATH="${SCRIPT_ROOT}/bin:${PATH}"
  else
    PROTOC=$(command -v protoc 2>/dev/null)
    if [[ ! -x "${PROTOC}" ]]; then
      kube::log::error "protoc 命令未找到。请将其安装到系统 PATH 或项目的 bin/protoc。"
      kube::log::error "访问 https://github.com/protocolbuffers/protobuf/releases 下载。"
                    return 1
                fi
  fi

  # 获取protoc版本
  PROTOC_VERSION=$(${PROTOC} --version 2>&1 | grep -o 'libprotoc [0-9]\+\.[0-9]\+\.' || echo "unknown")
  kube::log::info "使用protoc版本: ${PROTOC_VERSION}"

  # 使用API包查找函数来获取所有API包
  FOUND_API_PKGS=()
  kube::codegen::find_api_packages
  
  if [[ ${#FOUND_API_PKGS[@]} -eq 0 ]]; then
    kube::log::warning "未找到API包，跳过Protobuf代码生成"
    return 0
  fi
  
  # 构建包列表
  local packages=()
  for pkg in "${FOUND_API_PKGS[@]}"; do
    # 将包路径转换为正确格式 (APIS_PKG -> ROOT_PACKAGE/pkg/apis)
    pkg_path="${ROOT_PACKAGE}/pkg/apis/${pkg#${APIS_PKG}/}"
    packages+=("${pkg_path}")
    kube::log::info "添加Protobuf包: ${pkg_path}"
  done
  
  # 设置proto导入路径
  local proto_imports=()
  proto_imports+=("${SCRIPT_ROOT}")
  proto_imports+=("${GOPATH}/src")
  
  # 确保protoc-gen-go和protoc-gen-gogo可用
  protoc_gen_go=$(command -v protoc-gen-go 2>/dev/null || echo "${GOBIN}/protoc-gen-go")
  protoc_gen_gogo=$(command -v protoc-gen-gogo 2>/dev/null || echo "${GOBIN}/protoc-gen-gogo")
  
  if [[ ! -x "${protoc_gen_go}" ]]; then
    kube::log::warn "protoc-gen-go 未找到，可能会影响生成结果"
    kube::log::info "尝试安装: go install google.golang.org/protobuf/cmd/protoc-gen-go@latest"
  fi
  
  if [[ ! -x "${protoc_gen_gogo}" ]]; then
    kube::log::warn "protoc-gen-gogo 未找到，可能会影响生成结果"
    kube::log::info "尝试安装: go install k8s.io/code-generator/cmd/go-to-protobuf/protoc-gen-gogo@latest"
  fi
  
  # 设置输出目录
  local output_dir="${PROTO_OUTPUT_DIR:-${SCRIPT_ROOT}/pkg/apis}"
  mkdir -p "${output_dir}"
  
  # 构建命令参数
  local cmd_args=()
  
  # 添加proto导入路径
  for proto_import in "${proto_imports[@]}"; do
    cmd_args+=("--proto-import=${proto_import}")
  done
  
  # 添加包列表
  if [[ ${#packages[@]} -gt 0 ]]; then
    local pkg_str=$(IFS=','; echo "${packages[*]}")
    cmd_args+=("--packages=${pkg_str}")
  else
    kube::log::error "未指定要处理的包"
        return 1
    fi

  # 添加Go头文件
  cmd_args+=("--go-header-file=${BOILERPLATE}")
  
  # 添加输出目录
  cmd_args+=("--output-dir=${output_dir}")
  
  # 添加其他参数
  if [[ -n "${PROTO_EXTRA_ARGS:-}" ]]; then
    IFS=' ' read -ra extra_args <<< "${PROTO_EXTRA_ARGS}"
    for arg in "${extra_args[@]}"; do
      cmd_args+=("${arg}")
    done
  fi
  
  # 执行命令
  kube::log::info "执行: ${GO_TO_PROTOBUF} ${cmd_args[*]}"
  "${GO_TO_PROTOBUF}" "${cmd_args[@]}"
  
  # 验证结果
  local pb_count=$(find "${output_dir}" -name "*.pb.go" | wc -l)
  if [[ ${pb_count} -gt 0 ]]; then
    kube::log::status "Protobuf代码生成成功: 共 ${pb_count} 个文件"
    # 列出生成的文件
    find "${output_dir}" -name "*.pb.go" | sort | while read -r pb_file; do
      kube::log::info "✓ 生成: $(basename ${pb_file})"
    done
  else
    kube::log::warning "未找到生成的*.pb.go文件，生成可能不完整"
  fi
  
  kube::log::status "Protobuf代码生成完成"
}

# 入口函数，根据参数执行不同的生成任务
kube::codegen::main() {
  local arg=$1
  shift
  
  case "${arg}" in
    "all")
      kube::codegen::gen_deepcopy
      kube::codegen::generate_internal_apis_deepcopy_and_register
      kube::codegen::gen_register
      kube::codegen::gen_defaulter
      kube::codegen::gen_conversion
      kube::codegen::gen_validation
      kube::codegen::gen_applyconfiguration
      kube::codegen::gen_clientset
      kube::codegen::gen_lister
      kube::codegen::gen_informer
      kube::codegen::gen_openapi
      kube::codegen::gen_crd
      kube::codegen::gen_protobuf
      ;;
    "deepcopy")
      kube::codegen::gen_deepcopy
      ;;
    "register")
      kube::codegen::gen_register
      ;;
    "defaulter")
      kube::codegen::gen_defaulter
      ;;
    "conversion")
      kube::codegen::gen_conversion
      ;;
    "validation")
      kube::codegen::gen_validation
      ;;
    "applyconfiguration")
      kube::codegen::gen_applyconfiguration
      ;;
    "clientset")
      kube::codegen::gen_clientset
      ;;
   "lister")
      kube::codegen::gen_lister
      ;;
    "informer")
      kube::codegen::gen_informer
      ;;
    "openapi")
      kube::codegen::gen_openapi
      ;;
    "crd")
      kube::codegen::gen_crd
      ;;
    "protobuf")
      kube::codegen::gen_protobuf
      ;;
    "internal-essentials")
      kube::codegen::find_internal_api_packages
      kube::codegen::generate_internal_apis_deepcopy_and_register
      ;;
    *)
      echo "用法: $0 <命令>"
      echo "命令:"
      echo "  all                 - 为外部API版本生成所有标准代码 (deepcopy, register, clientset, listers, informers, openapi, crds, defaulters, conversions, validation, protobuf)"
      echo "  deepcopy            - 仅为外部API版本生成DeepCopy代码"
      echo "  register            - 仅为外部API版本生成Register代码"
      echo "  internal-essentials - 仅为内部API版本生成DeepCopy和Register代码"
      echo "  defaulter           - 仅为外部API版本生成Defaulter代码"
      echo "  conversion          - 仅为外部API版本生成Conversion代码"
      echo "  validation          - 仅为外部API版本生成Validation代码"
      echo "  applyconfiguration  - 仅为外部API版本生成ApplyConfiguration代码"
      echo "  clientset           - 仅为外部API版本生成Clientset代码"
      echo "  lister              - 仅为外部API版本生成Lister代码"
      echo "  informer            - 仅为外部API版本生成Informer代码"
      echo "  openapi             - 为外部API版本生成OpenAPI规范相关代码"
      echo "  crd                 - 为外部API版本生成CRD YAML清单"
      echo "  protobuf            - 为所有标记了protobuf的API版本(内外部)生成Protobuf相关代码"
      echo "  list-external-apis  - 列出脚本找到的所有外部API包路径"
      echo "  list-internal-apis  - 列出脚本找到的所有内部API包路径"
      echo ""
      echo "环境变量 (部分示例，可在 hack/lib/init.sh 或调用时设置):"
      echo "  API_ROOT:           API定义的物理路径根目录 (默认: ${PROJECT_ROOT}/pkg/apis)"
      echo "  APIS_PKG:           API定义的Go包路径根目录 (默认: ${ROOT_PACKAGE}/pkg/apis)"
      echo "  CLIENT_PKG:         生成的客户端代码的Go包路径根目录 (默认: ${ROOT_PACKAGE}/pkg/generated)"
      echo "  CLIENT_ROOT:        生成的客户端代码的物理输出目录根目录 (默认: ${PROJECT_ROOT}/pkg/generated)"
      echo "  CRD_OUTPUT_DIR:     CRD YAML文件输出目录 (默认: ${PROJECT_ROOT}/config/crd/bases)"
      echo "  API_GROUPS:         (可选) 指定要处理的API组列表 (如: 'iam.kubellm.io/v1alpha1,cluster.kubellm.io/v1alpha1')"
      echo "  ENABLE_DEEPCOPY:    (true/false) 控制是否启用deepcopy生成 (默认: true)"
      echo "  (其他 ENABLE_... 变量类似)"
      echo "  DEBUG:              (true/1) 启用更详细的日志输出"
      return 1
      ;;
  esac
  kubellm::log::status "命令 '${arg}' 执行完毕。"
}

# 如果直接执行脚本，则调用main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  kube::codegen::main "$@"
fi



