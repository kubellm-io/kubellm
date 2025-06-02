package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

/*
关于 metadata.name 作为用户名的思考：
- metadata.name 将被用作用户的登录名和系统内全局唯一的标识符。
  这利用了 Kubernetes 对资源名称唯一性的保证。
- 用户创建后，metadata.name 通常不应更改，以保证登录凭证的稳定性。
- 用户名的格式需要符合 Kubernetes 资源名称的规范 (例如，通常是小写字母、数字、'-'、'.')。

关于 spec.displayName：
- spec.displayName 用于用户在界面上展示的名称，用户可以根据需要修改此字段。
- 它与 metadata.name (登录名) 解耦，提供了更好的用户体验和灵活性。
*/

// User 是用户API的架构定义了系统中的一个用户及其相关信息。
// 用户是进行认证和授权的主体。
// metadata.name 被用作用户的登录名，必须全局唯一。
// +kubebuilder:object:root=true
// +kubebuilder:resource:categories="iam",scope="Cluster",shortName="usr"
// +kubebuilder:storageversion
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="DisplayName",type="string",JSONPath=".spec.displayName",description="用户的显示名称"
// +kubebuilder:printcolumn:name="Email",type="string",JSONPath=".spec.email",description="用户的电子邮件地址"
// +kubebuilder:printcolumn:name="Status",type="string",JSONPath=".status.state",description="用户的当前状态"
// +kubebuilder:printcolumn:name="LastLoginTime",type="date",JSONPath=".status.lastLoginTime",description="用户最后登录时间"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"
// +genclient:nonNamespaced
// +k8s:deepcopy-gen=true
// +k8s:openapi-gen=true
// +k8s:client-gen=true
// +genclient
// +k8s:validation-gen=true
// +k8s:defaulter-gen=true
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// User 用户资源定义
// @Description 用户是系统中进行认证和授权的主体。
// @APIVersion iam.kubellm.io/v1alpha1
// @Kind User
// @Resource scope="Cluster"
type User struct {
	metav1.TypeMeta `json:",inline"`
	// StandardObjectMeta是标准的Kubernetes对象元数据。
	// metadata.name 是用户的登录名，在集群中必须唯一。
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`

	// Spec 定义了用户的期望状态。
	// @Required true
	Spec UserSpec `json:"spec" protobuf:"bytes,2,opt,name=spec"`

	// Status 定义了用户的观察到的状态。
	// +optional
	Status UserStatus `json:"status,omitempty" protobuf:"bytes,3,opt,name=status"`
}

// UserSpec 定义用户的期望状态。
// @Description UserSpec包含用户的所有配置信息。
type UserSpec struct {
	// DisplayName 是用户的显示名称，用于UI展示。用户可以修改此字段。
	// @Description 用户的显示名称，可由用户自定义。
	// +optional
	// +kubebuilder:validation:MaxLength=128
	DisplayName string `json:"displayName,omitempty" protobuf:"bytes,2,opt,name=displayName"`

	// Email 是用户的唯一电子邮件地址，遵循RFC 5322规范。此字段为必需字段。
	// @Description 用户的唯一电子邮件地址。
	// @Required true
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Format=email
	// +kubebuilder:validation:MaxLength=254
	// +kubebuilder:validation:FieldSelector=true
	Email string `json:"email" protobuf:"bytes,1,opt,name=email"`

	// Password 存储用户密码的加密哈希值。
	// 此密码哈希由kubellm-auth-server在创建或更新用户时生成和管理。
	// 密码必须满足一定的复杂度要求。
	// @Description 用户密码的加密哈希值。此字段为只写（WriteOnly）或在特定条件下可更新，不应直接读取其内容。
	// @Format password
	// +optional
	// +kubebuilder:validation:MinLength=8
	// +kubebuilder:validation:MaxLength=128
	// 根据bcrypt哈希长度调整，或者如果存储原始密码则为64
	Password string `json:"password,omitempty" protobuf:"bytes,3,opt,name=password"`

	// Lang 是用户的首选语言代码，例如 "en-US", "zh-CN"。遵循BCP 47规范。
	// @Description 用户的首选语言代码 (例如 "en-US", "zh-CN")。
	// +optional
	// +kubebuilder:validation:MaxLength=32
	Lang string `json:"lang,omitempty" protobuf:"bytes,4,opt,name=lang"`

	// Description 是对用户的文本描述。
	// @Description 用户的详细描述信息。
	// +optional
	// +kubebuilder:validation:MaxLength=1024
	Description string `json:"description,omitempty" protobuf:"bytes,5,opt,name=description"`

	// Groups 是用户所属的组列表。组用于聚合权限。
	// @Description 用户所属的用户组名称列表。
	// +optional
	// +listType=set
	Groups []string `json:"groups,omitempty" protobuf:"bytes,6,rep,name=groups"`

	// PhoneNumber 是用户的电话号码。
	// @Description 用户的电话号码。
	// +optional
	// +kubebuilder:validation:MaxLength=32
	// +kubebuilder:validation:Pattern=`^\\+?[0-9\\s\\-\\(\\)]*$`
	PhoneNumber string `json:"phoneNumber,omitempty" protobuf:"bytes,7,opt,name=phoneNumber"`

	// Avatar 是用户头像的URL或标识符。
	// @Description 用户头像的URL或Base64编码的图像数据。
	// +optional
	// +kubebuilder:validation:MaxLength=2048
	// URL长度或base64大小限制
	Avatar string `json:"avatar,omitempty" protobuf:"bytes,8,opt,name=avatar"`

	// Department 是用户所属的部门或组织单元。
	// @Description 用户所属的部门或组织单元。
	// +optional
	// +kubebuilder:validation:MaxLength=256
	Department string `json:"department,omitempty" protobuf:"bytes,9,opt,name=department"`

	// Position 是用户的职位。
	// @Description 用户的职位信息。
	// +optional
	// +kubebuilder:validation:MaxLength=128
	Position string `json:"position,omitempty" protobuf:"bytes,10,opt,name=position"`

	// ExternalID 是用于关联外部系统用户的标识符 (例如，LDAP的entryUUID, OAuth提供者的sub等)。
	// 通常在通过外部身份提供者创建用户时设置。
	// @Description 关联的外部系统用户标识符。
	// +optional
	// +kubebuilder:validation:MaxLength=256
	ExternalID string `json:"externalID,omitempty" protobuf:"bytes,11,opt,name=externalID"`

	// IdentityProvider 指定创建此用户的身份提供者名称 (例如 'local', 'ldap', 'oidc-github')。
	// 如果为空，默认为 'local' 或由系统决定。
	// @Description 创建此用户的身份提供者名称。
	// +optional
	// +kubebuilder:validation:MaxLength=64
	IdentityProvider string `json:"identityProvider,omitempty" protobuf:"bytes,12,opt,name=identityProvider"`

	// LoginDisabled 指示用户是否被禁止登录。
	// 与 UserStatus 中的 State 不同，此字段为管理员控制，用于临时或永久禁止用户登录，而不改变其账户状态（如Active）。
	// @Description 管理员设置的用户登录禁用状态。true表示禁止登录。
	// +optional
	LoginDisabled *bool `json:"loginDisabled,omitempty" protobuf:"varint,15,opt,name=loginDisabled"`
}

// UserState 是用户账户的有效状态集合。
// @Description UserState定义了用户账户的几种可能状态。
type UserState string

// 用户账户的有效状态常量。
const (
	// UserActive 表示用户账户是活跃的，可以正常使用。
	// @Description 用户账户活跃状态。
	UserActive UserState = "Active"
	// UserDisabled 表示用户账户已被禁用，无法登录或执行操作。
	// @Description 用户账户禁用状态。
	UserDisabled UserState = "Disabled"
	// UserAuthLimitExceeded 表示用户因认证失败次数过多等原因，登录功能暂时受限。
	// @Description 用户认证尝试超限状态，登录可能被临时阻止。
	UserAuthLimitExceeded UserState = "AuthLimitExceeded"
	// UserLocked 表示用户账户已被管理员锁定，需要管理员干预才能解锁。
	// @Description 用户账户被锁定状态。
	UserLocked UserState = "Locked"
	// UserPendingApproval 表示用户账户等待审批，例如在新用户自注册后需要管理员审核通过。
	// @Description 用户账户等待审批状态。
	UserPendingApproval UserState = "PendingApproval"
	// UserPasswordExpired 表示用户密码已过期，需要重置密码。
	// @Description 用户密码已过期状态。
	UserPasswordExpired UserState = "PasswordExpired"
)

// UserStatus 定义用户的观察到的状态。
// @Description UserStatus包含了用户的运行时状态信息。
type UserStatus struct {
	// State 是用户当前的账户状态。
	// @Description 用户的当前计算状态 (例如 Active, Disabled, Locked)。
	// +optional
	State UserState `json:"state,omitempty" protobuf:"bytes,1,opt,name=state,casttype=UserState"`

	// Reason 是对当前状态的一个简短、人类可读的解释。
	// @Description 解释当前状态的原因。
	// +optional
	// +kubebuilder:validation:MaxLength=256
	Reason string `json:"reason,omitempty" protobuf:"bytes,2,opt,name=reason"`

	// Message 是对当前状态的更详细描述。
	// @Description 提供关于当前状态的更详细信息。
	// +optional
	// +kubebuilder:validation:MaxLength=1024
	Message string `json:"message,omitempty" protobuf:"bytes,3,opt,name=message"`

	// LastTransitionTime 是用户状态上一次发生变更的时间。
	// @Description 用户状态最后转换的时间戳。
	// +optional
	LastTransitionTime *metav1.Time `json:"lastTransitionTime,omitempty" protobuf:"bytes,4,opt,name=lastTransitionTime"`

	// LastLoginTime 是用户最后一次成功登录系统的时间。
	// @Description 用户最后成功登录的时间戳。
	// +optional
	LastLoginTime *metav1.Time `json:"lastLoginTime,omitempty" protobuf:"bytes,5,opt,name=lastLoginTime"`

	// LastLoginIP 是用户最后一次成功登录系统时使用的IP地址。
	// @Description 用户最后成功登录时使用的客户端IP地址。
	// +optional
	// +kubebuilder:validation:MaxLength=512
	// IPv6 + port
	LastLoginIP string `json:"lastLoginIp,omitempty" protobuf:"bytes,4,opt,name=lastLoginIp"`

	// FailedLoginAttempts 记录了近期连续登录失败的次数。达到一定阈值后可能会触发账户锁定或登录限制。
	// @Description 近期连续登录失败的次数。
	// +optional
	FailedLoginAttempts *int32 `json:"failedLoginAttempts,omitempty" protobuf:"varint,7,opt,name=failedLoginAttempts"`

	// PasswordExpiryTime 是用户当前密码的过期时间。如果为空，表示密码永不过期或策略未启用。
	// @Description 用户当前密码的过期时间。
	// +optional
	PasswordExpiryTime *metav1.Time `json:"passwordExpiryTime,omitempty" protobuf:"bytes,8,opt,name=passwordExpiryTime"`

	// PasswordLastChangedTime 是用户最后一次修改密码的时间。
	// @Description 用户最后一次修改密码的时间。
	// +optional
	PasswordLastChangedTime *metav1.Time `json:"passwordLastChangedTime,omitempty" protobuf:"bytes,9,opt,name=passwordLastChangedTime"`

	// Conditions 包含用户当前状态的结构化条件列表。
	// @Description 用户的当前状况的详细条件列表。
	// +optional
	// +patchMergeKey=type
	// +patchStrategy=merge
	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"type" protobuf:"bytes,10,rep,name=conditions"`
}

// +kubebuilder:object:root=true
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// UserList 包含用户列表。
// @Description UserList是User资源的集合。
type UserList struct {
	metav1.TypeMeta `json:",inline"`
	// StandardListMeta是标准的Kubernetes列表元数据。
	// +optional
	metav1.ListMeta `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`

	// Items 是User对象的列表。
	// @Required true
	Items []User `json:"items" protobuf:"bytes,2,rep,name=items"`
}
