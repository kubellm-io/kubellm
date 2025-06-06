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
// Code generated by applyconfiguration-gen. DO NOT EDIT.

package v1alpha1

import (
	v1 "k8s.io/api/core/v1"
	resource "k8s.io/apimachinery/pkg/api/resource"
)

// ResourceModelRangeApplyConfiguration represents a declarative configuration of the ResourceModelRange type for use
// with apply.
type ResourceModelRangeApplyConfiguration struct {
	Name *v1.ResourceName   `json:"name,omitempty"`
	Min  *resource.Quantity `json:"min,omitempty"`
	Max  *resource.Quantity `json:"max,omitempty"`
}

// ResourceModelRangeApplyConfiguration constructs a declarative configuration of the ResourceModelRange type for use with
// apply.
func ResourceModelRange() *ResourceModelRangeApplyConfiguration {
	return &ResourceModelRangeApplyConfiguration{}
}

// WithName sets the Name field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Name field is set to the value of the last call.
func (b *ResourceModelRangeApplyConfiguration) WithName(value v1.ResourceName) *ResourceModelRangeApplyConfiguration {
	b.Name = &value
	return b
}

// WithMin sets the Min field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Min field is set to the value of the last call.
func (b *ResourceModelRangeApplyConfiguration) WithMin(value resource.Quantity) *ResourceModelRangeApplyConfiguration {
	b.Min = &value
	return b
}

// WithMax sets the Max field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Max field is set to the value of the last call.
func (b *ResourceModelRangeApplyConfiguration) WithMax(value resource.Quantity) *ResourceModelRangeApplyConfiguration {
	b.Max = &value
	return b
}
