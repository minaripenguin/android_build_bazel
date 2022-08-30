"""
Copyright (C) 2022 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

load("//build/bazel/rules/aidl:interface.bzl", "aidl_interface")
load("//build/bazel/rules/aidl:library.bzl", "aidl_library")
load("//build/bazel/rules:gensrcs.bzl", "gensrcs")

test_scope = [
    "//build/bazel/rules/aidl/testing:aidl_interface_test",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-java",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-V1",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-V1-java",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-V2",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-V2-java",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-latest",
    "//build/bazel/rules/aidl/testing:aidl_interface_test-latest-java",
]

aidl_library(
    name = "aidl_library_test",
    srcs = ["Test.aidl"],
    tags = ["manual"],
)

aidl_interface(
    name = "aidl_interface_test",
    tags = ["manual"],
    versions = [
        "1",
        "2",
    ],
    deps = [":aidl_library_test"],
)

genquery(
    name = "generated_target_V1_has_correct_srcs_query",
    expression = 'kind("source file", deps(//build/bazel/rules/aidl/testing:aidl_interface_test-V1))',
    scope = test_scope,
)

genquery(
    name = "generated_target_V2_has_correct_srcs_query",
    expression = 'kind("source file", deps(//build/bazel/rules/aidl/testing:aidl_interface_test-V2))',
    scope = test_scope,
)

sh_test(
    name = "generated_targets_have_correct_srcs_test",
    size = "small",
    srcs = ["generated_targets_have_correct_srcs.sh"],
    data = [
        ":generated_target_V1_has_correct_srcs_query",
        ":generated_target_V2_has_correct_srcs_query",
    ],
    tags = [
        "manual",
        "no_windows",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)

genquery(
    name = "aidl_library_V1_produced_by_default_query",
    expression = "kind(aidl_library, //build/bazel/rules/aidl/testing:aidl_interface_test-V1)",
    scope = test_scope,
)

genquery(
    name = "aidl_library_V2_produced_by_default_query",
    expression = "kind(aidl_library, //build/bazel/rules/aidl/testing:aidl_interface_test-V2)",
    scope = test_scope,
)

genquery(
    name = "aidl_library_latest_produced_by_default_query",
    expression = "kind(alias, //build/bazel/rules/aidl/testing:aidl_interface_test-latest)",
    scope = test_scope,
)

genquery(
    name = "aidl_library_unversioned_produced_by_default_query",
    expression = "kind(alias, //build/bazel/rules/aidl/testing:aidl_interface_test)",
    scope = test_scope,
)

genquery(
    name = "java_backend_V1_produced_by_default_query",
    expression = "kind(java_aidl_library, //build/bazel/rules/aidl/testing:aidl_interface_test-V1-java)",
    scope = test_scope,
)

genquery(
    name = "java_backend_V2_produced_by_default_query",
    expression = "kind(java_aidl_library, //build/bazel/rules/aidl/testing:aidl_interface_test-V2-java)",
    scope = test_scope,
)

genquery(
    name = "java_backend_latest_produced_by_default_query",
    expression = "kind(alias, //build/bazel/rules/aidl/testing:aidl_interface_test-latest-java)",
    scope = test_scope,
)

genquery(
    name = "java_backend_unversioned_produced_by_default_query",
    expression = "kind(alias, //build/bazel/rules/aidl/testing:aidl_interface_test-java)",
    scope = test_scope,
)

sh_test(
    name = "interface_macro_produces_all_targets_test",
    size = "small",
    srcs = ["interface_macro_produces_all_targets.sh"],
    data = [
        ":aidl_library_V1_produced_by_default_query",
        ":aidl_library_V2_produced_by_default_query",
        ":aidl_library_latest_produced_by_default_query",
        ":aidl_library_unversioned_produced_by_default_query",
        ":java_backend_V1_produced_by_default_query",
        ":java_backend_V2_produced_by_default_query",
        ":java_backend_latest_produced_by_default_query",
        ":java_backend_unversioned_produced_by_default_query",
    ],
    tags = [
        "manual",
        "no_windows",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)