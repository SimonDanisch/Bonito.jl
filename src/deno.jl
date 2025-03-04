using esbuild_jll

function deno_bundle(path_to_js::AbstractString, output_file::String)
    iswriteable = filemode(output_file) & Base.S_IWUSR != 0
    # bundles shipped as part of a package end up as read only
    # So we can't overwrite them
    isfile(output_file) && !iswriteable && return false, "Output file is not writeable"
    stdout = IOBuffer()
    err = IOBuffer()
    cmd = `$(esbuild_jll.esbuild()) $path_to_js --bundle --outfile=$output_file`
    try
        run(pipeline(cmd; stdout=stdout, stderr=err))
    catch e
        err_str = String(take!(err))
        return false, err_str
    end
    return isfile(output_file), ""
end
