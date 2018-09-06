def create_compilation_dir(js, js_source_provider, compilation_dir):
    """Creates a directory with the sources described in the JsSource object

    Args:
      js: JsContext object
      js_source_provider: JsSource object describing the sources to symlink in the directory
      compilation_dir: File object for the
    """

    # Depset with all of the sources in it
    inputs = depset(
        transitive = [js_source_provider.all_sources],
    )

    source_files = js_source_provider.all_sources

    script_args = js.script_args(Label("//internal/common/actions/create_compilation_dir/create_compilation_dir.js"))

    js.run_js(js, inputs = inputs, outputs = [compilation_dir], script_args)
