function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return
    s = get_server()
    close(s)
    GLOBAL_SERVER[] = nothing
end
