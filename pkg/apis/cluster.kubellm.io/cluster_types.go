package cluster

import (
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	// ResourceKindCluster is kind name of Cluster.
	ResourceKindCluster = "Cluster"
	// ResourceSingularCluster is singular name of Cluster.
	ResourceSingularCluster = "cluster"
	// ResourcePluralCluster is plural name of Cluster.
	ResourcePluralCluster = "clusters"
	// ResourceNamespaceScopedCluster indicates if Cluster is NamespaceScoped.
	ResourceNamespaceScopedCluster = false

	ClusterConditionReady = "Ready"
)

const (
	// SecretTokenKey is the name of secret token key.
	SecretTokenKey = "token"
	// SecretCADataKey is the name of secret caBundle key.
	SecretCADataKey = "caBundle"
)

// +kubebuilder:subresource:status
// +kubebuilder:object:root=true
// +genclient:nonNamespaced
// +k8s:deepcopy-gen=true
// +k8s:openapi-gen=true
// +k8s:client-gen=true
// +genclient
// +k8s:validation-gen=true
// +k8s:defaulter-gen=true
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// Cluster represents the desired state and status of a member cluster.
type Cluster struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// Spec represents the specification of the desired behavior of member cluster.
	Spec ClusterSpec `json:"spec"`

	// Status represents the status of member cluster.
	// +optional
	Status ClusterStatus `json:"status,omitempty"`
}


// ClusterSpec defines the desired state of a member cluster.
type ClusterSpec struct {
	// ID is the unique identifier for the cluster.
	// It is different from the object uid(.metadata.uid) and is typically collected automatically
	// from each member cluster during the process of registration.
	//
	// The value is collected in order:
	// 1. If the registering cluster enabled ClusterProperty API and defined the cluster ID by
	//   creating a ClusterProperty object with name 'cluster.clusterset.k8s.io', Kubellm would
	//   take the defined value in the ClusterProperty object.
	//   See https://github.com/kubernetes-sigs/about-api for more details about ClusterProperty API.
	// 2. Take the uid of 'kube-system' namespace on the registering cluster.
	//
	// Please don't update this value unless you know what you are doing, because
	// it will/may be used to :
	// - uniquely identify the clusters within the Kubellm system.
	// - compose the DNS name of multi-cluster services.
	//
	// +optional
	// +kubebuilder:validation:Maxlength=128000
	ID string `json:"id,omitempty"`

	// DisplayName is the display name of the cluster.
	// +optional
	DisplayName string `json:"displayName,omitempty"`

	// SyncMode describes how a cluster syncs resources from kubellm control plane.
	// +kubebuilder:validation:Enum=Push;Pull
	// +required
	// SyncMode ClusterSyncMode `json:"syncMode"`

	// The API endpoint of the member cluster. This can be a hostname,
	// hostname:port, IP or IP:port.
	// +optional
	APIEndpoint string `json:"apiEndpoint,omitempty"`

	// SecretRef represents the secret that contains mandatory credentials to access the member cluster.
	// The secret should hold credentials as follows:
	// - secret.data.token
	// - secret.data.caBundle
	// +optional
	SecretRef *LocalSecretReference `json:"secretRef,omitempty"`
	// ImpersonatorSecretRef represents the secret that contains the token of impersonator.
	// The secret should hold credentials as follows:
	// - secret.data.token
	// +optional
	ImpersonatorSecretRef *LocalSecretReference `json:"impersonatorSecretRef,omitempty"`

	// InsecureSkipTLSVerification indicates that the kubellm control plane should not confirm the validity of the serving
	// certificate of the cluster it is connecting to. This will make the HTTPS connection between the kubellm control
	// plane and the member cluster insecure.
	// Defaults to false.
	// +optional
	InsecureSkipTLSVerification bool `json:"insecureSkipTLSVerification,omitempty"`

	// ProxyURL is the proxy URL for the cluster.
	// If not empty, the kubellm control plane will use this proxy to talk to the cluster.
	// For more details please refer to: https://github.com/kubernetes/client-go/issues/351
	// +optional
	ProxyURL string `json:"proxyURL,omitempty"`

	// ProxyHeader is the HTTP header required by proxy server.
	// The key in the key-value pair is HTTP header key and the value is the associated header payloads.
	// For the header with multiple values, the values should be separated by comma(e.g. 'k1': 'v1,v2,v3').
	// +optional
	ProxyHeader map[string]string `json:"proxyHeader,omitempty"`

	// Provider represents the cloud provider name of the member cluster.
	// +optional
	Provider string `json:"provider,omitempty"`

	// Region represents the region in which the member cluster is located.
	// +optional
	Region string `json:"region,omitempty"`

	// Taints are attached to the member cluster.
	// Taints on the cluster have the "effect" on
	// any resource that does not tolerate the Taint.
	// +optional
	Taints []corev1.Taint `json:"taints,omitempty"`

	// ResourceModels is the list of resource modeling in this cluster. Each modeling quota can be customized by the user.
	// Modeling name must be one of the following: cpu, memory, storage, ephemeral-storage.
	// If the user does not define the modeling name and modeling quota, it will be the default model.
	// The default model grade from 0 to 8.
	// When grade = 0 or grade = 1, the default model's cpu quota and memory quota is a fix value.
	// When grade greater than or equal to 2, each default model's cpu quota is [2^(grade-1), 2^grade), 2 <= grade <= 7
	// Each default model's memory quota is [2^(grade + 2), 2^(grade + 3)), 2 <= grade <= 7
	// E.g. grade 0 likes this:
	// - grade: 0
	//   ranges:
	//   - name: "cpu"
	//     min: 0 C
	//     max: 1 C
	//   - name: "memory"
	//     min: 0 GB
	//     max: 4 GB
	//
	// - grade: 1
	//   ranges:
	//   - name: "cpu"
	//     min: 1 C
	//     max: 2 C
	//   - name: "memory"
	//     min: 4 GB
	//     max: 16 GB
	//
	// - grade: 2
	//   ranges:
	//   - name: "cpu"
	//     min: 2 C
	//     max: 4 C
	//   - name: "memory"
	//     min: 16 GB
	//     max: 32 GB
	//
	// - grade: 7
	//   range:
	//   - name: "cpu"
	//     min: 64 C
	//     max: 128 C
	//   - name: "memory"
	//     min: 512 GB
	//     max: 1024 GB
	//
	// grade 8, the last one likes below. No matter what Max value you pass,
	// the meaning of Max value in this grade is infinite. You can pass any number greater than Min value.
	// - grade: 8
	//   range:
	//   - name: "cpu"
	//     min: 128 C
	//     max: MAXINT
	//   - name: "memory"
	//     min: 1024 GB
	//     max: MAXINT
	//
	// +optional
	ResourceModels []ResourceModel `json:"resourceModels,omitempty"`
}

// LocalSecretReference is a reference to a secret within the enclosing
// namespace.
type LocalSecretReference struct {
	// Namespace is the namespace for the resource being referenced.
	Namespace string `json:"namespace"`

	// Name is the name of the resource being referenced.
	Name string `json:"name"`
}

// +k8s:deepcopy-gen=true
// ResourceModel describes the modeling that you want to statistics.
type ResourceModel struct {
	// Grade is the index for the resource modeling.
	// +required
	Grade uint `json:"grade"`

	// Ranges describes the resource quota ranges.
	// +required
	Ranges []ResourceModelRange `json:"ranges"`
}

// +k8s:deepcopy-gen=true
// +k8s:openapi-gen=true
// ResourceModelRange describes the detail of each modeling quota that ranges from min to max.
// Please pay attention, by default, the value of min can be inclusive, and the value of max cannot be inclusive.
// E.g. in an interval, min = 2, max = 10 is set, which means the interval [2,10).
// This rule ensures that all intervals have the same meaning. If the last interval is infinite,
// it is definitely unreachable. Therefore, we define the right interval as the open interval.
// For a valid interval, the value on the right is greater than the value on the left,
// in other words, max must be greater than min.
// It is strongly recommended that the [Min, Max) of all ResourceModelRanges can make a continuous interval.
type ResourceModelRange struct {
	// Name is the name for the resource that you want to categorize.
	// +required
	Name corev1.ResourceName `json:"name"`

	// Min is the minimum amount of this resource represented by resource name.
	// Note: The Min value of first grade(usually 0) always acts as zero.
	// E.g. [1,2) equal to [0,2).
	// +required
	Min resource.Quantity `json:"min"`

	// Max is the maximum amount of this resource represented by resource name.
	// Special Instructions, for the last ResourceModelRange, which no matter what Max value you pass,
	// the meaning is infinite. Because for the last item,
	// any ResourceModelRange's quota larger than Min will be classified to the last one.
	// Of course, the value of the Max field is always greater than the value of the Min field.
	// It should be true in any case.
	// +required
	Max resource.Quantity `json:"max"`
}

// ClusterStatus contains information about the current status of a
// cluster updated periodically by cluster controller.
type ClusterStatus struct {
	// KubernetesVersion represents version of the member cluster.
	// +optional
	KubernetesVersion string `json:"kubernetesVersion,omitempty"`

	// APIEnablements represents the list of APIs installed on the member cluster.
	// +optional
	APIEnablements []APIEnablement `json:"apiEnablements,omitempty"`

	// Conditions is an array of current cluster conditions.
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// NodeSummary represents the summary of nodes status in the member cluster.
	// +optional
	NodeSummary *NodeSummary `json:"nodeSummary,omitempty"`

	// ResourceSummary represents the summary of resources in the member cluster.
	// +optional
	ResourceSummary *ResourceSummary `json:"resourceSummary,omitempty"`

	// RemedyActions represents the remedy actions that needs to be performed
	// on the cluster.
	// +optional
	RemedyActions []string `json:"remedyActions,omitempty"`
}

// +k8s:deepcopy-gen=true
// APIEnablement is a list of API resource, it is used to expose the name of the
// resources supported in a specific group and version.
type APIEnablement struct {
	// GroupVersion is the group and version this APIEnablement is for.
	GroupVersion string `json:"groupVersion"`
	// Resources is a list of APIResource.
	// +optional
	Resources []APIResource `json:"resources,omitempty"`
}

// +k8s:deepcopy-gen=true
// APIResource specifies the name and kind names for the resource.
type APIResource struct {
	// Name is the plural name of the resource.
	// +required
	Name string `json:"name"`
	// Kind is the kind for the resource (e.g. 'Deployment' is the kind for resource 'deployments')
	// +required
	Kind string `json:"kind"`
}

// +k8s:deepcopy-gen=true
// NodeSummary represents the summary of nodes status in a specific cluster.
type NodeSummary struct {
	// TotalNum is the total number of nodes in the cluster.
	// +optional
	TotalNum int32 `json:"totalNum,omitempty"`
	// ReadyNum is the number of ready nodes in the cluster.
	// +optional
	ReadyNum int32 `json:"readyNum,omitempty"`
}

// +k8s:deepcopy-gen=true
// ResourceSummary represents the summary of resources in the member cluster.
type ResourceSummary struct {
	// Allocatable represents the resources of a cluster that are available for scheduling.
	// Total amount of allocatable resources on all nodes.
	// +optional
	Allocatable corev1.ResourceList `json:"allocatable,omitempty"`

	// Allocating represents the resources of a cluster that are pending for scheduling.
	// Total amount of required resources of all Pods that are waiting for scheduling.
	// +optional
	Allocating corev1.ResourceList `json:"allocating,omitempty"`

	// Allocated represents the resources of a cluster that have been scheduled.
	// Total amount of required resources of all Pods that have been scheduled to nodes.
	// +optional
	Allocated corev1.ResourceList `json:"allocated,omitempty"`

	// AllocatableModelings represents the statistical resource modeling.
	// +optional
	AllocatableModelings []AllocatableModeling `json:"allocatableModelings,omitempty"`
}

// +k8s:deepcopy-gen=true
// AllocatableModeling represents the number of nodes in which allocatable resources in a specific resource model grade.
// E.g. AllocatableModeling{Grade: 2, Count: 10} means 10 nodes belong to resource model in grade 2.
type AllocatableModeling struct {
	// Grade is the index of ResourceModel.
	// +required
	Grade uint `json:"grade"`

	// Count is the number of nodes that own the resources delineated by this modeling.
	// +required
	Count int `json:"count"`
}

// +k8s:deepcopy-gen=true
// +kubebuilder:object:root=true
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// ClusterList contains a list of member clusters
type ClusterList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`

	// Items holds a list of Cluster.
	Items []Cluster `json:"items"`
}

// +k8s:conversion-gen:explicit-from=net/url.Values
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// ClusterProxyOptions is the query options to a Cluster's proxy call.
// type ClusterProxyOptions struct {
// 	metav1.TypeMeta `json:",inline"`

// 	// Path is the part of URLs that include clusters, suffixes,
// 	// and parameters to use for the current proxy request to cluster.
// 	// For example, the whole request URL is
// 	// http://localhost/apis/cluster.karmada.io/v1alpha1/cluster/{clustername}/proxy/api/v1/nodes
// 	// Path is api/v1/nodes
// 	// +optional
// 	Path string `json:"path,omitempty" protobuf:"bytes,1,opt,name=path"`
// }

// +k8s:deepcopy-gen=true
// +k8s:conversion-gen:explicit-from=net/url.Values
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// ClusterProxyOptions is the query options to a Cluster's proxy call.
type ClusterProxyOptions struct {
	metav1.TypeMeta `json:",inline"`

	// Path is the part of URLs that include clusters, suffixes,
	// and parameters to use for the current proxy request to cluster.
	// For example, the whole request URL is
	// http://localhost/apis/cluster.karmada.io/v1alpha1/cluster/{clustername}/proxy/api/v1/nodes
	// Path is api/v1/nodes
	// +optional
	Path string `json:"path,omitempty" protobuf:"bytes,1,opt,name=path"`
}
