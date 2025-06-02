# KubeLLM - Kubernetes-Native Large Language Model Platform

## 项目概述

KubeLLM 是一个遵循 Kubernetes API 聚合架构模式的企业级大语言模型管理平台。项目严格遵循 Kubernetes 开发范式，提供声明式 API、控制器模式和可扩展的插件体系。

## 架构设计

### 1. 核心设计原则

- **API 聚合模式 (API Aggregation)**：作为独立的 API 服务器，扩展 Kubernetes API
- **声明式 API**：所有资源遵循 Kubernetes 资源模型
- **控制器模式**：使用 Reconciliation Loop 确保最终一致性
- **高内聚低耦合**：清晰的模块边界和接口定义
- **可观测性优先**：内置 metrics、tracing、structured logging

### 2. 项目结构

```
kubellm-refactord/
├── cmd/                            # 命令行入口
│   ├── kubellm-apiserver/         # API Server 主程序
│   │   ├── main.go               # 入口文件
│   │   └── app/                  # 应用逻辑
│   │       ├── options/          # 命令行选项（统一配置源）
│   │       └── server/           # 服务器启动逻辑
│   └── kubellm-controller/        # 控制器管理器
│       └── app/
├── pkg/                           # 公共库代码
│   ├── apis/                      # API 定义层（仅类型定义）
│   │   ├── iam.kubellm.io/       # IAM 资源组
│   │   │   ├── types.go          # 内部版本类型
│   │   │   ├── v1alpha1/         # 外部版本 v1alpha1
│   │   │   └── register.go       # 注册逻辑
│   │   └── cluster.kubellm.io/   # 集群资源组
│   ├── generated/                 # 代码生成器输出（只读）
│   │   ├── clientset/            # 类型安全的客户端
│   │   ├── listers/              # 缓存列表器
│   │   └── informers/            # 共享 Informer
│   ├── registry/                  # 存储层（细粒度拆分）
│   │   ├── iam/                  # IAM 资源存储
│   │   │   ├── user/            # 用户资源
│   │   │   │   ├── storage.go  # 存储实现
│   │   │   │   ├── strategy.go # 策略模式
│   │   │   │   └── rest.go     # REST 接口
│   │   │   └── role/           # 角色资源
│   │   └── cluster/             # 集群资源存储
│   ├── service/                  # 业务服务层（领域逻辑）
│   │   ├── auth/                # 认证服务
│   │   │   ├── interface.go    # 接口定义
│   │   │   └── impl.go         # 实现
│   │   └── user/                # 用户服务
│   ├── controller/              # 控制器实现
│   │   ├── user/               # 用户控制器
│   │   └── cluster/            # 集群控制器
│   └── informer/               # 独立的 Informer 库
│       ├── factory.go          # 工厂模式
│       └── typed/              # 类型化 Informer
├── internal/                    # 内部实现（不对外暴露）
│   ├── config/                 # 统一配置管理
│   │   ├── types.go           # 配置类型定义
│   │   ├── loader.go          # 配置加载器
│   │   └── validator.go       # 配置验证
│   ├── middleware/             # HTTP 中间件
│   │   ├── auth.go           # 认证中间件
│   │   ├── audit.go          # 审计中间件
│   │   └── metrics.go        # 指标中间件
│   ├── utils/                 # 工具函数
│   └── metrics/               # 指标定义
├── hack/                      # 开发脚本
│   ├── update-all.sh         # 更新所有生成代码
│   ├── verify-all.sh         # 验证代码
│   └── codegen.sh            # 代码生成脚本
├── tools/                     # 开发工具
├── docs/                      # 文档
│   ├── architecture/         # 架构文档
│   └── api/                  # API 文档
└── test/                      # 测试
    ├── integration/          # 集成测试
    └── e2e/                  # 端到端测试
```

### 3. API 设计规范

#### 3.1 资源定义规范

所有资源必须遵循 Kubernetes 资源模型：

```go
// 内部版本（pkg/apis/iam.kubellm.io/types.go）
type User struct {
    metav1.TypeMeta
    metav1.ObjectMeta
    
    Spec   UserSpec
    Status UserStatus
}

// 外部版本（pkg/apis/iam.kubellm.io/v1alpha1/types.go）
// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
type User struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    
    Spec   UserSpec   `json:"spec,omitempty"`
    Status UserStatus `json:"status,omitempty"`
}
```

#### 3.2 API 分组

- `iam.kubellm.io`: 身份认证和授权相关资源
- `cluster.kubellm.io`: 集群管理相关资源
- `model.kubellm.io`: 模型管理相关资源（未来）

### 4. 存储层设计

#### 4.1 分层架构

```
REST Handler → Strategy → Store → Etcd
```

#### 4.2 核心组件

- **REST**: 处理 HTTP 请求，实现标准 REST 语义
- **Strategy**: 业务逻辑，如验证、默认值、准入控制
- **Store**: 通用存储逻辑，处理 etcd 交互

#### 4.3 分页实现

所有 List 操作必须支持分页：

```go
type ListOptions struct {
    Limit    int64  // 每页大小
    Continue string // 继续令牌
}
```

### 5. 服务层设计

#### 5.1 接口驱动开发

```go
// pkg/service/auth/interface.go
type AuthService interface {
    Authenticate(ctx context.Context, username, password string) (*User, error)
    Authorize(ctx context.Context, user *User, verb, resource string) (bool, error)
}
```

#### 5.2 依赖注入

```go
// internal/config/provider.go
type ServiceProvider struct {
    AuthService auth.AuthService
    UserService user.UserService
}
```

### 6. 控制器设计

#### 6.1 Reconciliation Loop

```go
func (c *UserController) Reconcile(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
    // 1. 获取资源
    // 2. 检查期望状态
    // 3. 执行操作
    // 4. 更新状态
}
```

#### 6.2 事件驱动

使用 Informer 监听资源变化，触发 Reconciliation。

### 7. 配置管理

#### 7.1 统一配置源

所有配置通过 `cmd/*/app/options` 定义，避免重复：

```go
type Options struct {
    *genericoptions.ServerRunOptions
    *genericoptions.EtcdOptions
    Authentication *AuthenticationOptions
    Features       *FeatureOptions
}
```

#### 7.2 配置验证

```go
func (o *Options) Validate() []error {
    var errs []error
    // 验证逻辑
    return errs
}
```

### 8. 日志规范

- **语言**: 英文日志输出
- **格式**: 结构化日志（JSON）
- **级别**: Info, Warning, Error, Fatal
- **示例**:
```go
klog.V(2).InfoS("User created", 
    "user", user.Name, 
    "namespace", user.Namespace,
    "elapsed", time.Since(start))
```

### 9. 代码注释规范

- **语言**: 中文注释
- **内容**: 重点说明业务逻辑和使用场景
- **示例**:
```go
// CreateUser 创建新用户
// 该方法会进行以下处理：
// 1. 验证用户名唯一性
// 2. 密码加密存储
// 3. 分配默认角色
// 使用场景：管理员通过 Web 界面或 CLI 创建新用户
func CreateUser(ctx context.Context, user *User) error {
    // 实现逻辑
}
```

## 开发流程

### 1. API 定义

1. 在 `pkg/apis/<group>` 定义内部版本类型
2. 在 `pkg/apis/<group>/<version>` 定义外部版本
3. 添加代码生成标记

### 2. 代码生成

```bash
# 更新所有生成代码
./hack/update-all.sh

# 验证生成代码
./hack/verify-all.sh
```

### 3. 存储实现

1. 实现 Strategy 接口
2. 创建 REST 存储
3. 注册到 API Server

### 4. 服务实现

1. 定义服务接口
2. 实现业务逻辑
3. 编写单元测试

### 5. 控制器实现

1. 定义 Reconciler
2. 设置 Watch
3. 实现业务逻辑

## 构建和部署

### 1. 本地开发

```bash
# 构建
make build

# 运行测试
make test

# 启动 API Server
./bin/kubellm-apiserver --etcd-servers=http://localhost:2379
```

### 2. 容器化

```bash
# 构建镜像
make docker-build

# 推送镜像
make docker-push
```

### 3. Kubernetes 部署

```bash
# 部署 CRD
kubectl apply -f deploy/crds/

# 部署 API Server
kubectl apply -f deploy/apiserver/

# 部署控制器
kubectl apply -f deploy/controller/
```

## 监控和运维

### 1. Metrics

- 使用 Prometheus 格式暴露指标
- 端点: `/metrics`
- 主要指标:
  - API 请求延迟
  - 资源操作计数
  - 控制器队列深度

### 2. 健康检查

- `/healthz`: 健康状态
- `/readyz`: 就绪状态
- `/livez`: 存活状态

### 3. 日志聚合

支持输出到:
- 标准输出（结构化 JSON）
- 文件（滚动）
- 远程日志服务

## 版本策略

- **API 版本**: 遵循 Kubernetes API 版本规范（alpha → beta → stable）
- **向后兼容**: 至少支持前两个版本
- **废弃策略**: 提前两个版本通知

## 安全考虑

1. **认证**: 支持多种认证方式（Token, Certificate, OIDC）
2. **授权**: 基于 RBAC 的细粒度权限控制
3. **审计**: 完整的操作审计日志
4. **加密**: TLS 通信，敏感数据加密存储

## 性能优化

1. **缓存策略**: 使用 Informer 本地缓存
2. **并发控制**: 限制并发请求数
3. **批量操作**: 支持批量创建/更新
4. **索引优化**: 为常用查询字段建立索引

## 贡献指南

1. Fork 项目
2. 创建特性分支
3. 提交代码（遵循 commit 规范）
4. 创建 Pull Request
5. 代码审查

## 许可证

Apache License 2.0 