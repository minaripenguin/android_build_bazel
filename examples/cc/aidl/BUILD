load("//build/bazel/rules/aidl:library.bzl", "aidl_library")
load("//build/bazel/rules/cc:cc_aidl_library.bzl", "cc_aidl_library")

aidl_library(
    name = "abcd",
    srcs = ["a/b/c/d/ABCD.aidl"],
    strip_import_prefix = "a/b",
)

# Similar to cc_proto_library, output path for generated code is
# bazel-bin/<abcd_cc_aidl_library package dir>/abcd_cc_aidl_library_aidl_code_gen/<abcd package dir>/_virtual_imports/abcd/c/d
#
# AIDL sources are symlinked to bazel-bin/<abcd package dir>/_virtual_imports/abcd/c/d
cc_aidl_library(
    name = "abcd_cc_aidl_library",
    deps = [":abcd"],
)

aidl_library(
    name = "foo",
    srcs = ["foo/IFoo.aidl"],
    visibility = ["//build/bazel/examples/cc/aidl_library:__subpackages__"],
)