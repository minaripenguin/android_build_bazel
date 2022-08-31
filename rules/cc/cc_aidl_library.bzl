"""
Copyright (C) 2022 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under thes License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

load("//build/bazel/rules/aidl:library.bzl", "AidlGenInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(":cc_library_common.bzl", "create_ccinfo_for_includes")
load("//build/bazel/rules/cc:cc_library_static.bzl", "cc_library_static")

_SOURCES = "sources"
_HEADERS = "headers"
_INCLUDE_DIR = "include_dir"

def cc_aidl_library(
        name,
        lang = "cpp",
        deps = [],
        implementation_deps = [],
        dynamic_deps = [],
        **kwargs):
    """
    Generate AIDL stub code for C++ and wrap it in a cc_library_static target

    Args:
        name:               (String) name of the cc_library_static target
        deps:               (list[AidlGenInfo]) list of all aidl_libraries that this
                            this cc_aidl_library depends on
        lang:               (String) AIDL backend
        implementation_deps (list[CcInfo]) internal dependencies of the created cc_library_static target
        dynamic_deps        (list[CcInfo]) dynamic dependencies of the created cc_library_static target
    """
    aidl_code_gen = name + "_aidl_code_gen"
    _cc_aidl_code_gen(
        name = aidl_code_gen,
        deps = deps,
        lang = lang,
        **kwargs
    )

    if lang == "cpp":
        cc_library_static(
            name = name,
            srcs = [":" + aidl_code_gen],
            # The generated headers from aidl_code_gen include the headers in
            # :libbinder_headers. All cc library/binary targets that depends on
            # cc_aidl_library needs to to explicitly include
            # //frameworks/native/libs/binder:libbinder which re-exports
            # //frameworks/native/libs/binder:libbinder_headers
            implementation_deps = [
                "//frameworks/native/libs/binder:libbinder_headers",
            ] + implementation_deps,
            deps = [aidl_code_gen],
            dynamic_deps = dynamic_deps,
            **kwargs
        )
    elif lang == "ndk":
        cc_library_static(
            name = name,
            srcs = [":" + aidl_code_gen],
            implementation_deps = implementation_deps,
            deps = [aidl_code_gen],
            dynamic_deps = dynamic_deps,
            **kwargs
        )

def _cc_aidl_code_gen_impl(ctx):
    """
    Generate stub C++ code from direct aidl srcs using transitive deps

    Args:
        ctx: (RuleContext)
    Returns:
        (DefaultInfo) Generated .cpp and .cpp.d files
        (CcInfo)      Generated headers and their include dirs
    """
    generated_srcs, generated_hdrs, include_dirs = [], [], []

    for aidl_info in [d[AidlGenInfo] for d in ctx.attr.deps]:
        stub = _compile_aidl_srcs(ctx, aidl_info, ctx.attr.lang)
        generated_srcs.extend(stub[_SOURCES])
        generated_hdrs.extend(stub[_HEADERS])
        include_dirs.extend([stub[_INCLUDE_DIR]])

    return [
        DefaultInfo(files = depset(direct = generated_srcs + generated_hdrs)),
        create_ccinfo_for_includes(
            ctx,
            hdrs = generated_hdrs,
            includes = include_dirs,
        ),
    ]

_cc_aidl_code_gen = rule(
    implementation = _cc_aidl_code_gen_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [AidlGenInfo],
        ),
        "_aidl": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            default = Label("//prebuilts/build-tools:linux-x86/bin/aidl"),
        ),
        "lang": attr.string(
            default = "cpp",
            values = ["cpp", "ndk"],
        ),
    },
    provides = [CcInfo],
)

def _declare_stub_files(ctx, aidl_file, direct_include_dir, lang):
    """Declare stub files that AIDL compiles to for cc

    Args:
      ctx:                   (Context) Used to register declare_file actions.
      aidl_file:             (File) The aidl file
      direct_include_dir     (String) The path to given aidl file minus the aidl package namespace
      lang                   (String) AIDL backend
    Returns:
      (list[File]) List of declared stub files
    """
    ret = {}
    ret[_SOURCES], ret[_HEADERS] = [], []
    short_basename = paths.replace_extension(aidl_file.basename, "")

    # aidl file path relative to direct include dir
    short_path = paths.relativize(aidl_file.path, direct_include_dir)

    ret[_SOURCES] = [
        ctx.actions.declare_file(
            paths.join(
                ctx.label.name,
                paths.dirname(short_path),
                short_basename + ".cpp",
            ),
        ),
    ]

    headers = [short_basename + ".h"]

    # https://cs.android.com/android/platform/superproject/+/master:build/soong/cc/gen.go;bpv=1;bpt=1?q=cc%2Fgen.go
    # Strip prefix I before creating basenames for bp and bn headers
    if len(short_basename) > 2 and short_basename.startswith("I") and short_basename[1].upper() == short_basename[1]:
        short_basename = short_basename.removeprefix("I")

    headers.extend([
        "Bp" + short_basename + ".h",
        "Bn" + short_basename + ".h",
    ])

    # Headers for ndk backend are nested under aidl directory to prevent
    # c++ namespaces collision with cpp backend
    # Context: https://android.googlesource.com/platform/system/tools/aidl/+/7c93337add97ce36f0a35c6705f3a67a441f2ae7
    out_dir_prefix = ""
    if lang == "ndk":
        out_dir_prefix = "aidl"

    for basename in headers:
        ret[_HEADERS].append(ctx.actions.declare_file(
            paths.join(ctx.label.name, out_dir_prefix, paths.dirname(short_path), basename),
        ))

    return ret

def _compile_aidl_srcs(ctx, aidl_info, lang):
    """Compile AIDL stub code for direct AIDL srcs

    Args:
      ctx:        (Context) Used to register declare_file actions
      aidl_info:  (AidlGenInfo) aidl_info from an aidl library
      lang:       (String) AIDL backend
    Returns:
      (Dict)      A dict of where the the values are generated headers (.h) and their boilerplate implementation (.cpp)
    """

    ret = {}
    ret[_SOURCES], ret[_HEADERS] = [], []

    # transitive_include_dirs is traversed in preorder
    direct_include_dir = aidl_info.transitive_include_dirs.to_list()[0]

    # Given AIDL file a/b/c/d/Foo.aidl with direct_include_dir a/b
    # The outputs paths are
    #  cpp backend:
    #   <package-dir>/<target-name>/c/d/*Foo.h
    #   <package-dir>/<target-name>/c/d/Foo.cpp
    #  ndk backend:
    #   <package-dir>/<target-name>/aidl/c/d/*Foo.h
    #   <package-dir>/<target-name>/c/d/Foo.cpp
    #
    # where <package-dir> is bazel-bin/<path-to-cc_aidl_library-target>
    # and   <target-name> is <cc_aidl_library-name>_aidl_code_gen
    # cpp and ndk are created in separate cc_aidl-library targets, so
    # <target-name> are unique among cpp and ndk backends

    # include dir, relative to package dir, to the generated headers
    ret[_INCLUDE_DIR] = ctx.label.name

    # AIDL needs to know the full path to outputs
    # <bazel-bin>/<package-dir>/<target-name>
    out_dir = paths.join(
        ctx.bin_dir.path,
        ctx.label.package,
        ret[_INCLUDE_DIR],
    )

    outputs = []
    for aidl_file in aidl_info.srcs.to_list():
        files = _declare_stub_files(ctx, aidl_file, direct_include_dir, lang)
        outputs.extend(files[_SOURCES] + files[_HEADERS])
        ret[_SOURCES].extend(files[_SOURCES])
        ret[_HEADERS].extend(files[_HEADERS])

    args = ctx.actions.args()
    args.add_all(aidl_info.flags)
    args.add_all([
        "--ninja",
        "--lang={}".format(lang),
        "--out={}".format(out_dir),
        "--header_out={}".format(out_dir),
    ])
    args.add_all(["-I {}".format(i) for i in aidl_info.transitive_include_dirs.to_list()])
    args.add_all(["{}".format(aidl_file.path) for aidl_file in aidl_info.srcs.to_list()])

    ctx.actions.run(
        inputs = aidl_info.transitive_srcs,
        outputs = outputs,
        executable = ctx.executable._aidl,
        arguments = [args],
        progress_message = "Compiling AIDL binding",
    )

    return ret
