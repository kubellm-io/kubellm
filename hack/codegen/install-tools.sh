#!/usr/bin/env bash

# Copyright 2025 The Kubellm Authors.
#
# 安装代码生成所需的所有工具

set -o errexit
set -o nounset
set -o pipefail

# 加载初始化脚本
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "${PROJECT_ROOT}/hack/lib/init.sh"

# 命令行参数
FORCE_INSTALL=false
if [[ $# -gt 0 && "$1" == "--force" ]]; then
  FORCE_INSTALL=true
  kubellm::log::info "强制安装模式已启用"
fi

kubellm::log::info "开始安装代码生成工具..."

# 设置代码生成器版本，可以根据需要修改
CODE_GENERATOR_VERSION="${CODE_GENERATOR_VERSION:-v0.32.3}"
CONTROLLER_TOOLS_VERSION="${CONTROLLER_TOOLS_VERSION:-latest}"
KUBE_OPENAPI_VERSION="${KUBE_OPENAPI_VERSION:-latest}"
PROTOBUF_VERSION="${PROTOBUF_VERSION:-latest}"  

# 安装代码生成工具
install_tools() {
  kubellm::log::info "安装 k8s.io/code-generator 工具 (${CODE_GENERATOR_VERSION})..."
  
  # applyconfiguration-gen 生成应用配置代码
  kubellm::log::info "- 安装 applyconfiguration-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/applyconfiguration-gen@${CODE_GENERATOR_VERSION}
  
  # client-gen 生成客户端代码
  kubellm::log::info "- 安装 client-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/client-gen@${CODE_GENERATOR_VERSION}
  
  # conversion-gen 生成版本转换代码
  kubellm::log::info "- 安装 conversion-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/conversion-gen@${CODE_GENERATOR_VERSION}
  
  # deepcopy-gen 生成深拷贝函数
  kubellm::log::info "- 安装 deepcopy-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/deepcopy-gen@${CODE_GENERATOR_VERSION}
  
  # defaulter-gen 生成默认值设置代码
  kubellm::log::info "- 安装 defaulter-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/defaulter-gen@${CODE_GENERATOR_VERSION}
  
  # validation-gen 生成验证代码
  # 0.32.3没有validation-gen
  # kubellm::log::info "- 安装 validation-gen..."
  # GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/validation-gen@${CODE_GENERATOR_VERSION}

  # go-to-protobuf 生成protobuf定义
  kubellm::log::info "- 安装 go-to-protobuf..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/go-to-protobuf@${CODE_GENERATOR_VERSION}
  
  # informer-gen 生成informer代码
  kubellm::log::info "- 安装 informer-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/informer-gen@${CODE_GENERATOR_VERSION}
  
  # lister-gen 生成lister代码
  kubellm::log::info "- 安装 lister-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/lister-gen@${CODE_GENERATOR_VERSION}
  
  # register-gen 生成API注册代码
  kubellm::log::info "- 安装 register-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/register-gen@${CODE_GENERATOR_VERSION}
  
  kubellm::log::info "安装 k8s.io/kube-openapi 工具 (${KUBE_OPENAPI_VERSION})..."
  # openapi-gen 生成OpenAPI规范
  kubellm::log::info "- 安装 openapi-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/kube-openapi/cmd/openapi-gen@${KUBE_OPENAPI_VERSION}
  
  kubellm::log::info "安装 sigs.k8s.io/controller-tools 工具 (${CONTROLLER_TOOLS_VERSION})..."
  # controller-gen 生成CRD、rbac等
  kubellm::log::info "- 安装 controller-gen..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_TOOLS_VERSION}

  kubellm::log::info "安装 google.golang.org/protobuf/cmd/protoc-gen-go 工具 (${PROTOBUF_VERSION})..."
  kubellm::log::info "- 安装 protoc-gen-go..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOBUF_VERSION}

  kubellm::log::info "安装 k8s.io/code-generator/cmd/go-to-protobuf/protoc-gen-gogo 工具 (${CODE_GENERATOR_VERSION})..."
  kubellm::log::info "- 安装 protoc-gen-gogo..."
  GOBIN="${GOBIN:-${GOPATH}/bin}" go install k8s.io/code-generator/cmd/go-to-protobuf/protoc-gen-gogo@${CODE_GENERATOR_VERSION}
}

# 获取工具版本
get_tool_version() {
  local tool=$1
  local version=""
  
  # 针对不同工具使用不同的版本检查方法
  case "${tool}" in
    "controller-gen")
      version=$(${tool} -v 2>/dev/null | tr -d '\n' || echo "未知版本")
      ;;
    "protoc-gen-go")
      version=$(${tool} -v 2>/dev/null || echo "未知版本") 
      ;;
    *)
      # K8s code-generator工具没有直接的版本标志，尝试使用帮助信息判断
      version="已安装"
      ;;
  esac
  
  echo "${version}"
}

# 检查工具是否已安装
check_tools() {
  local missing_tools=()
  local tools_found=0
  local tools_total=0
  
  # 要检查的工具列表
  local tools=(
    "applyconfiguration-gen"
    "client-gen"
    "conversion-gen"
    "deepcopy-gen"
    "defaulter-gen"
    # 0.32.3没有实现这个validation-gen 功能
    # "validation-gen" 
    "go-to-protobuf"
    "informer-gen"
    "lister-gen"
    "register-gen"
    "openapi-gen"
    "controller-gen"
    "protoc-gen-go"
    "protoc-gen-gogo"
  )
  
  kubellm::log::info "检查工具安装情况..."
  
  tools_total=${#tools[@]}
  
  for tool in "${tools[@]}"; do
    if command -v "${tool}" > /dev/null 2>&1; then
      version=$(get_tool_version "${tool}")
      kubellm::log::info "✓ ${tool} - ${version}"
      ((tools_found++))
    else
      kubellm::log::warn "✗ ${tool} - 未安装"
      missing_tools+=("${tool}")
    fi
  done
  
  kubellm::log::info "已安装: ${tools_found}/${tools_total} 工具"
  
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    kubellm::log::warn "未安装工具: ${missing_tools[*]}"
    return 1
  fi
  
  return 0
}

# 主函数
main() {
  # 检查工具是否已安装
  if [[ "${FORCE_INSTALL}" == "true" ]]; then
    kubellm::log::info "跳过检查，强制安装所有工具"
  elif check_tools; then
    kubellm::log::info "所有代码生成工具已安装"
    return 0
  fi
  
  # 安装缺失的工具
  install_tools
  
  # 再次检查
  if check_tools; then
    kubellm::log::info "所有代码生成工具安装成功"
    return 0
  else
    kubellm::log::fatal "工具安装失败，请检查错误信息"
  fi
}

# 执行主函数
main "$@"