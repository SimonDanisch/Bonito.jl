if VERSION < v"1.3-"
    using Base.PCRE
    Base.:(^)(r::Regex, i::Integer) = Regex(string("(?:", r.pattern, "){$i}"), r.compile_options, r.match_options)
    function Base.:(*)(r1::Union{Regex,AbstractString,AbstractChar}, rs::Union{Regex,AbstractString,AbstractChar}...)
        mask = PCRE.CASELESS | PCRE.MULTILINE | PCRE.DOTALL | PCRE.EXTENDED # imsx
        match_opts   = nothing # all args must agree on this
        compile_opts = nothing # all args must agree on this
        shared = mask
        for r in (r1, rs...)
            r isa Regex || continue
            if match_opts === nothing
                match_opts = r.match_options
                compile_opts = r.compile_options & ~mask
            else
                r.match_options == match_opts &&
                    r.compile_options & ~mask == compile_opts ||
                    throw(ArgumentError("cannot multiply regexes: incompatible options"))
            end
            shared &= r.compile_options
        end
        unshared = mask & ~shared
        Regex(string(wrap_string(r1, unshared), wrap_string.(rs, Ref(unshared))...), compile_opts | shared, match_opts)
    end

    Base.:(*)(r::Regex) = r # avoids wrapping r in a useless subpattern
    wrap_string(r::Regex, unshared::UInt32) = string("(?", regex_opts_str(r.compile_options & unshared), ':', r.pattern, ')')
# if s contains raw"\E", split '\' and 'E' within two distinct \Q...\E groups:
    wrap_string(s::AbstractString, ::UInt32) =  string("\\Q", replace(s, raw"\E" => raw"\\E\QE"), "\\E")
    wrap_string(s::AbstractChar, ::UInt32) = string("\\Q", s, "\\E")

    regex_opts_str(opts) = (isassigned(_regex_opts_str) ? _regex_opts_str[] : init_regex())[opts]

# UInt32 to String mapping for some compile options
    const _regex_opts_str = Ref{Base.ImmutableDict{UInt32,String}}()

    init_regex() = _regex_opts_str[] = foldl(0:15, init=Base.ImmutableDict{UInt32,String}()) do d, o
        opt = UInt32(0)
        str = ""
        if o & 1 != 0
            opt |= PCRE.CASELESS
            str *= 'i'
        end
        if o & 2 != 0
            opt |= PCRE.MULTILINE
            str *= 'm'
        end
        if o & 4 != 0
            opt |= PCRE.DOTALL
            str *= 's'
        end
        if o & 8 != 0
            opt |= PCRE.EXTENDED
            str *= 'x'
        end
        Base.ImmutableDict(d, opt => str)
    end
end
