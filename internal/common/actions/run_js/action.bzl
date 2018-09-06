load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def run_js(
        js,
        inputs,
        outputs,
        script_args):
    """Create action that uses nodejs to run an internal .js file

    This is intended to be used internally by bazel-javascript and should
    only have access to the node_modules that bazel-javascript installs internally

    Args:
      js: JsContext object.
      inputs: additional depset of action inputs (e.g. source files)
      outputs: the outputs that the action generates as a sequence of Files
      script_to_run: .js File to run
      script_args: arguments to pass to the js file
    """

    action_inputs = depset(
        direct = [
            script_to_run,
            "//internal/common/actions:BazelAction.js",
            js._internal_packages[NpmPackagesInfo].installed_dir,
        ],
        transitive = [
            inputs,
        ],
    )

    env = {
        "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules",
    }

    js.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = ctx._internal_nodejs,
        arguments = script_args,
        env = env,
    )
