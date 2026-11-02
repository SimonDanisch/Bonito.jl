function HTTPServer.apply_handler(folder::Folder, context)
    target = context.request.target[2:end] # first should be '/' which we want to remove for a path
    path = abspath(joinpath(folder.path, target))
    if isfile(path)
        _, ext = splitext(path)
        body = read(path)
        # TODO: use HTTPServer.file_mimetype
        if ext == ".html"
            # Bonito.html is just a simple helper to return a HTTP html response
            return Bonito.html(body)
        elseif ext == ".css"
            return HTTP.Response(200, ["Content-Type" => "text/css", "charset" => "utf-8"], body=body)
        elseif ext == ".js"
            return HTTP.Response(200, ["Content-Type" => "text/javascript", "charset" => "utf-8"],
                                 body=body)
        else
            @warn "Cannot deal with $ext"
            return Bonito.HTTPServer.response_404()  # not appropriate! I don't know what to do here.
        end
    else
        @warn "Did not find $target ($path), returning 404"
        return Bonito.HTTPServer.response_404()
    end
end
