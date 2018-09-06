load("//internal/common/actions:actions.bzl", "create_compilation_dir", "run_js")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

###############################################################################
# Providers

# Wrapper for rule ctx that should be created through js_context
JsContext = provider()

# Javascript compilation sources
JsSource = provider(fields = [
    # Path of the BUILD.bazel file relative to the workspace root.
    "build_file_path",
    # Source files provided as input.
    "sources",
    # All source files
    "all_sources",
    # Depset of npm_packages
    "npm_packages",
])

# Javascript files that can be included as a built dependency
JsLibrary = provider(fields = [
    # JsSource object for the source used to build the library
    "source",
    # Directory with the compiled sources (like pkg.lib)
    "library_dir",
])

# Collection of js libraries that can be imported and
JsPackage = provider(
    fields = [
        # JsLibrary object for the
        "library",
        # Name that will be used for non relative imports
        "package_name",
    ],
)

###############################################################################
# Helpers

def _js_source(js, attr):
    """Create a JsSource provider with attr.srcs and the sources from attr.deps

    Args:
    js: JsContext object
    attr: rule attributes to extract srcs and deps from
    """

    # The srcs should contain what has been explicitly added for a rule
    srcs_attr = getattr(attr, "srcs", [])

    # The deps is list of labels that should have providers that we can get sources from
    deps_attr = getattr(attr, "deps", [])

    all_transitive_sources = [dep[JsSource].all_sources for dep in deps_attr if JsSource in dep]

    all_sources = depset(
        direct = srcs_attr,
        transitive = all_transitive_sources,
    )

    direct_npm_packages = [dep[NpmPackagesInfo] for dep in ctx.attr.deps if NpmPackagesInfo in dep]
    if len(direct_npm_packages) > 1:
        fail("Found more than one set of NPM packages in target definition: " + ",".join([
            dep.label
            for dep in direct_npm_packages
        ]))

    extended_npm_packages = depset(
        direct = direct_npm_packages,
        transitive = [
            dep[JsLibraryInfo].npm_packages
            for dep in ctx.attr.deps
            if JsLibraryInfo in dep
        ],
    )
    npm_packages_list = extended_npm_packages.to_list()
    if len(npm_packages_list) > 1:
        fail("Found more than one set of NPM packages through dependencies: " + ",".join([
            dep.label
            for dep in npm_packages_list
        ]))

    return JsSource(
        build_file_path = js.build_file_path,
        sources = srcs_attr,
        all_sources = internal_deps,
        npm_packages = extended_npm_packages,
    )

def _js_library(js, name, source):
    """Create a JsLibrary provider

    Args:
      js: JsContext object
    """

def _script_args(js, script_file):
    """Create Args object that can be used with js.run_js()

    Args:
    js: JsContext object
    script_file: File object for the script to be run
    """
    if not script_file is File:
        fail("script_file not supplied to script_args")

    args = js.actions.args()

    # Add the script to run
    args.add(script_file)

    # If the args get too big then spill over into the param file
    args.use_param_file("--param=%s")
    args.set_param_file_format("multiline")

# Following pattern similar to rules_go
# https://github.com/bazelbuild/rules_go/blob/2179a6e1b576fc2a309c6cf677ad40e5b7f999ba/go/private/context.bzl#L207
def js_context(ctx, attr = None):
    if not attr:
        attr = ctx.attr

    # Node js to be used to run javascript backed bazel actions
    _internal_nodejs = getattr(attr, "_internal_nodejs", Label("@nodejs//:node"))

    # Packages that will be made available to javascript backed bazel actions
    _internal_packages = getattr(attr, "_internal_packages", Label("//internal/packages"))

    # Packages that will be used if none are provided
    _empty_npm_packages = getattr(attr, "_empty_npm_packages", Label("//internal/npm_packages/empty:packages"))

    return JsContext(
        # Fields
        workspace_name = ctx.workspace_name,
        build_file_path = ctx.build_file_path,
        _ctx = ctx,
        _internal_nodejs = _internal_nodejs,
        _internal_packages = _internal_packages,
        _empty_npm_packages = _empty_npm_packages,

        #Actions
        actions = ctx.actions,
        create_compilation_dir = create_compilation_dir,
        run_js = run_js,

        #Helpers
        script_args = _script_args,
        js_source = _js_source,
    )
