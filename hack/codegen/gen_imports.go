// 此文件只用于导入代码生成工具包，使go.mod能正确添加这些依赖

package main

import (
	// 代码生成相关导入
	_ "k8s.io/code-generator/cmd/applyconfiguration-gen"
	_ "k8s.io/code-generator/cmd/client-gen"
	_ "k8s.io/code-generator/cmd/conversion-gen"
	_ "k8s.io/code-generator/cmd/deepcopy-gen"
	_ "k8s.io/code-generator/cmd/defaulter-gen"
	_ "k8s.io/code-generator/cmd/go-to-protobuf"
	_ "k8s.io/code-generator/cmd/informer-gen"
	_ "k8s.io/code-generator/cmd/lister-gen"
	_ "k8s.io/code-generator/cmd/register-gen"

	// 0.32.3没有validation-gen
	// _ "k8s.io/code-generator/cmd/validation-gen"

	// OpenAPI生成
	_ "k8s.io/kube-openapi/cmd/openapi-gen"

	// Controller工具
	_ "sigs.k8s.io/controller-tools/cmd/controller-gen"

	// Protobuf工具
	_ "google.golang.org/grpc/cmd/protoc-gen-go-grpc"
	_ "google.golang.org/protobuf/cmd/protoc-gen-go"
	_ "k8s.io/code-generator/cmd/go-to-protobuf/protoc-gen-gogo"

	_ "k8s.io/api/admissionregistration/v1"
	_ "k8s.io/api/autoscaling/v2"
	_ "k8s.io/api/core/v1"
	_ "k8s.io/api/networking/v1"
	_ "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	_ "k8s.io/apimachinery/pkg/api/resource"
	_ "k8s.io/apimachinery/pkg/apis/meta/v1"
	_ "k8s.io/apimachinery/pkg/runtime"
	_ "k8s.io/apimachinery/pkg/version"
	_ "k8s.io/metrics/pkg/apis/custom_metrics"
	_ "k8s.io/metrics/pkg/apis/custom_metrics/v1beta1"
	_ "k8s.io/metrics/pkg/apis/custom_metrics/v1beta2"
	_ "k8s.io/metrics/pkg/apis/external_metrics"
	_ "k8s.io/metrics/pkg/apis/external_metrics/v1beta1"
	_ "k8s.io/metrics/pkg/apis/metrics"
	_ "k8s.io/metrics/pkg/apis/metrics/v1beta1"
)
