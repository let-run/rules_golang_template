def _render_impl(ctx):
    render = ctx.executable._render
    template = ctx.file.template
    literal_values = ctx.attr.literal_values
    out = ctx.outputs.out
    json_data_out = ctx.outputs.json_data_out

    file_data_values = ctx.attr.file_data_values
    json_data_values = ctx.attr.json_data_values

    file_input_args = []
    file_input_files = []

    values = dict()

    for k,v in literal_values.items() : 
        values[k] = v

    for label,key in file_data_values.items() : 
        values[key] = struct(__FILE__ = label.files.to_list()[0].path)
        file_input_files.append(label.files.to_list()[0])

    for label,key in json_data_values.items() : 
        values[key] = struct(__JSON__ = label.files.to_list()[0].path)
        file_input_files.append(label.files.to_list()[0])


    outputs = [out]

    values_json = ctx.actions.declare_file(ctx.label.name + '.input-values.json')
    outputs.append(values_json)
    ctx.actions.write(values_json, struct(**values).to_json())
 
    ctx.actions.run(
        mnemonic = "RenderTemplate",
        inputs = [
            values_json,
            template,
        ] + file_input_files,
        executable=render,
        tools=[render],
        arguments=[
            "--values="+values_json.path, 
            "--template="+template.path, 
            "--output="+out.path,
            "--data_output="+json_data_out.path]
            + file_input_args,
        outputs = [json_data_out, out],
    )

    return [DefaultInfo(files = depset(outputs))]


_render = rule(
    implementation = _render_impl,
    attrs = {
        "extension": attr.string(
            doc="The filename extension to use for the template output",
            mandatory = True,
        ),
        "template": attr.label(
            doc="The template file to use as input to the template render",
            allow_single_file = True,
            mandatory = True,
        ),
        "file_data_values": attr.label_keyed_string_dict(
            doc="A map<string:label> to import the text content of each file into the template rendering context",
            allow_files=True,
            mandatory=False,
            allow_empty=True,
            default = {}
        ),
        "json_data_values": attr.label_keyed_string_dict(
            doc="A map<string:label> to import the parsed json value of each file into the template rendering context",
            allow_files=True,
            mandatory=False,
            allow_empty=True,
            default = {}
        ),
        "literal_values": attr.string_dict(
            doc="A map<string:string> of values to import into the template context",
            allow_empty=True, 
            default={}, 
            mandatory=True, 
            allow_empty=True
        ),
        # The label to the crd definition 'hybrises.modelt.hybris.com'
        "_render": attr.label(
            default = Label("//render:render"),
            allow_single_file = True,
            executable = True,
            cfg = "host",
        ),
    },
    outputs = {
        "out": "%{name}.%{extension}", # the rendered file
        "json_data_out":"%{name}.values.json" # the values used to render the file.
    },
)

def golang_template(**kwargs):
    if "file_data_values" in kwargs : 
        kwargs["file_data_values"] = dict([[v,k] for k,v in kwargs["file_data_values"].items()])

    if "json_data_values" in kwargs : 
        kwargs["json_data_values"] = dict([[v,k] for k,v in kwargs["json_data_values"].items()])
    _render(**kwargs)

