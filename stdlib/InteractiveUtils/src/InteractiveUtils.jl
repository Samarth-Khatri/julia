# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
The `InteractiveUtils` module provides utilities for interactive use of Julia,
such as code introspection and clipboard access.
It is intended for interactive work and is loaded automatically in interactive mode.
"""
module InteractiveUtils

Base.Experimental.@optlevel 1

export apropos, edit, less, code_warntype, code_llvm, code_native, methodswith, varinfo,
    versioninfo, subtypes, supertypes, @which, @edit, @less, @functionloc, @code_warntype,
    @code_typed, @code_lowered, @code_llvm, @code_native, @time_imports, clipboard, @trace_compile, @trace_dispatch,
    @activate

import Base.Docs.apropos

using Base: unwrap_unionall, rewrap_unionall, isdeprecated, Bottom, summarysize,
    signature_type, format_bytes
using Base.Libc
using Markdown

include("editless.jl")
include("codeview.jl")
include("macros.jl")
include("clipboard.jl")

"""
    varinfo(m::Module=Main, pattern::Regex=r""; all=false, imported=false, recursive=false, sortby::Symbol=:name, minsize::Int=0)

Return a markdown table giving information about public global variables in a module, optionally restricted
to those matching `pattern`.

The memory consumption estimate is an approximate lower bound on the size of the internal structure of the object.

- `all` : also list non-public objects defined in the module, deprecated objects, and compiler-generated objects.
- `imported` : also list objects explicitly imported from other modules.
- `recursive` : recursively include objects in sub-modules, observing the same settings in each.
- `sortby` : the column to sort results by. Options are `:name` (default), `:size`, and `:summary`.
- `minsize` : only includes objects with size at least `minsize` bytes. Defaults to `0`.

The output of `varinfo` is intended for display purposes only.  See also [`names`](@ref) to get an array of symbols defined in
a module, which is suitable for more general manipulations.
"""
function varinfo(m::Module=Base.active_module(), pattern::Regex=r""; all::Bool = false, imported::Bool = false, recursive::Bool = false, sortby::Symbol = :name, minsize::Int=0)
    sortby in (:name, :size, :summary) || throw(ArgumentError("Unrecognized `sortby` value `:$sortby`. Possible options are `:name`, `:size`, and `:summary`"))
    rows = Vector{Any}[]
    workqueue = [(m, ""),]
    while !isempty(workqueue)
        m2, prep = popfirst!(workqueue)
        for v in names(m2; all, imported)
            if !isdefined(m2, v) || !occursin(pattern, string(v))
                continue
            end
            value = getglobal(m2, v)
            isbuiltin = value === Base || value === Base.active_module() || value === Core
            if recursive && !isbuiltin && isa(value, Module) && value !== m2 && nameof(value) === v && parentmodule(value) === m2
                push!(workqueue, (value, "$prep$v."))
            end
            ssize_str, ssize = if isbuiltin
                    ("", typemax(Int))
                else
                    ss = summarysize(value)
                    (format_bytes(ss), ss)
                end
            if ssize >= minsize
                push!(rows, Any[string(prep, v), ssize_str, summary(value), ssize])
            end
        end
    end
    let (col, rev) = if sortby === :name
            1, false
        elseif sortby === :size
            4, true
        elseif sortby === :summary
            3, false
        else
            @assert "unreachable"
        end
        sort!(rows; by=r->r[col], rev)
    end
    pushfirst!(rows, Any["name", "size", "summary"])

    return Markdown.MD(Any[Markdown.Table(map(r->r[1:3], rows), Symbol[:l, :r, :l])])
end
varinfo(pat::Regex; kwargs...) = varinfo(Base.active_module(), pat; kwargs...)

"""
    versioninfo(io::IO=stdout; verbose::Bool=false)

Print information about the version of Julia in use. The output is
controlled with boolean keyword arguments:

- `verbose`: print all additional information

!!! warning "Warning"
    The output of this function may contain sensitive information. Before sharing the output,
    please review the output and remove any data that should not be shared publicly.

See also: [`VERSION`](@ref).
"""
function versioninfo(io::IO=stdout; verbose::Bool=false)
    println(io, "Julia Version $VERSION")
    if !isempty(Base.GIT_VERSION_INFO.commit_short)
        println(io, "Commit $(Base.GIT_VERSION_INFO.commit_short) ($(Base.GIT_VERSION_INFO.date_string))")
    end
    official_release = Base.TAGGED_RELEASE_BANNER == "Official https://julialang.org release"
    if Base.isdebugbuild() || !isempty(Base.TAGGED_RELEASE_BANNER) || (Base.GIT_VERSION_INFO.tagged_commit && !official_release)
        println(io, "Build Info:")
        if Base.isdebugbuild()
            println(io, "  DEBUG build")
        end
        if !isempty(Base.TAGGED_RELEASE_BANNER)
            println(io, "  ", Base.TAGGED_RELEASE_BANNER)
        end
        if Base.GIT_VERSION_INFO.tagged_commit && !official_release
            println(io,
                """

                    Note: This is an unofficial build, please report bugs to the project
                    responsible for this build and not to the Julia project unless you can
                    reproduce the issue using official builds available at https://julialang.org
                """
            )
        end
    end
    println(io, "Platform Info:")
    println(io, "  OS: ", Sys.iswindows() ? "Windows" : Sys.isapple() ?
        "macOS" : Sys.KERNEL, " (", Sys.MACHINE, ")")

    if verbose
        lsb = ""
        if Sys.islinux()
            try lsb = readchomp(pipeline(`lsb_release -ds`, stderr=devnull)); catch; end
        end
        if Sys.iswindows()
            try lsb = strip(read(`$(ENV["COMSPEC"]) /c ver`, String)); catch; end
        end
        if !isempty(lsb)
            println(io, "      ", lsb)
        end
        if Sys.isunix()
            println(io, "  uname: ", readchomp(`uname -mprsv`))
        end
    end

    if verbose
        cpuio = IOBuffer() # print cpu_summary with correct alignment
        Sys.cpu_summary(cpuio)
        for (i, line) in enumerate(split(chomp(takestring!(cpuio)), "\n"))
            prefix = i == 1 ? "  CPU: " : "       "
            println(io, prefix, line)
        end
    else
        cpu = Sys.cpu_info()
        println(io, "  CPU: ", length(cpu), " × ", cpu[1].model)
    end

    if verbose
        println(io, "  Memory: $(Sys.total_memory()/2^30) GB ($(Sys.free_memory()/2^20) MB free)")
        try println(io, "  Uptime: $(Sys.uptime()) sec"); catch; end
        print(io, "  Load Avg: ")
        Base.print_matrix(io, Sys.loadavg()')
        println(io)
    end
    println(io, "  WORD_SIZE: ", Sys.WORD_SIZE)
    println(io, "  LLVM: libLLVM-",Base.libllvm_version," (", Sys.JIT, ", ", Sys.CPU_NAME, ")")
    println(io, "  GC: ", unsafe_string(ccall(:jl_gc_active_impl, Ptr{UInt8}, ())))
    println(io, """Threads: $(Threads.nthreads(:default)) default, $(Threads.nthreads(:interactive)) interactive, \
      $(Threads.ngcthreads()) GC (on $(Sys.CPU_THREADS) virtual cores)""")

    function is_nonverbose_env(k::String)
        return occursin(r"^JULIA_|^DYLD_|^LD_", k)
    end
    function is_verbose_env(k::String)
        return occursin(r"PATH|FLAG|^TERM$|HOME", k) && !is_nonverbose_env(k)
    end
    env_strs = String[
        String["  $(k) = $(v)" for (k,v) in ENV if is_nonverbose_env(uppercase(k))];
        (verbose ?
         String["  $(k) = $(v)" for (k,v) in ENV if is_verbose_env(uppercase(k))] :
         String[]);
    ]
    if !isempty(env_strs)
        println(io, "Environment:")
        for str in env_strs
            println(io, str)
        end
    end
end


function type_close_enough(@nospecialize(x), @nospecialize(t))
    x == t && return true
    # TODO: handle UnionAll properly
    return (isa(x, DataType) && isa(t, DataType) && x.name === t.name && x <: t) ||
           (isa(x, Union) && isa(t, DataType) && (type_close_enough(x.a, t) || type_close_enough(x.b, t)))
end

# `methodswith` -- shows a list of methods using the type given
"""
    methodswith(typ[, module or function]; supertypes::Bool=false)

Return an array of methods with an argument of type `typ`.

The optional second argument restricts the search to a particular module or function
(the default is all top-level modules).

If keyword `supertypes` is `true`, also return arguments with a parent type of `typ`,
excluding type `Any`.

See also: [`methods`](@ref).
"""
function methodswith(@nospecialize(t::Type), @nospecialize(f::Base.Callable), meths = Method[]; supertypes::Bool=false)
    for d in methods(f)
        if any(function (x)
                   let x = rewrap_unionall(x, d.sig)
                       (type_close_enough(x, t) ||
                        (supertypes ? (isa(x, Type) && t <: x && (!isa(x,TypeVar) || x.ub != Any)) :
                         (isa(x,TypeVar) && x.ub != Any && t == x.ub)) &&
                        x != Any)
                   end
               end,
               unwrap_unionall(d.sig).parameters)
            push!(meths, d)
        end
    end
    return meths
end

function _methodswith(@nospecialize(t::Type), m::Module, supertypes::Bool)
    meths = Method[]
    for nm in names(m)
        if isdefinedglobal(m, nm)
            f = getglobal(m, nm)
            if isa(f, Base.Callable)
                methodswith(t, f, meths; supertypes = supertypes)
            end
        end
    end
    return unique(meths)
end

methodswith(@nospecialize(t::Type), m::Module; supertypes::Bool=false) = _methodswith(t, m, supertypes)

function methodswith(@nospecialize(t::Type); supertypes::Bool=false)
    meths = Method[]
    for mod in Base.loaded_modules_array()
        append!(meths, _methodswith(t, mod, supertypes))
    end
    return unique(meths)
end

# subtypes
function _subtypes_in!(mods::Array, x::Type)
    xt = unwrap_unionall(x)
    if !isabstracttype(x) || !isa(xt, DataType)
        # Fast path
        return Type[]
    end
    sts = Vector{Any}()
    while !isempty(mods)
        m = pop!(mods)
        xt = xt::DataType
        for s in names(m, all = true)
            if !isdeprecated(m, s) && isdefinedglobal(m, s)
                t = getglobal(m, s)
                dt = isa(t, UnionAll) ? unwrap_unionall(t) : t
                if isa(dt, DataType)
                    if dt.name.name === s && dt.name.module == m && supertype(dt).name == xt.name
                        ti = typeintersect(t, x)
                        ti != Bottom && push!(sts, ti)
                    end
                elseif isa(t, Module) && nameof(t) === s && parentmodule(t) === m && t !== m
                    t === Base || push!(mods, t) # exclude Base, since it also parented by Main
                end
            end
        end
    end
    return permute!(sts, sortperm(map(string, sts)))
end

subtypes(m::Module, x::Type) = _subtypes_in!([m], x)

"""
    subtypes(T::DataType)

Return a list of immediate subtypes of DataType `T`. Note that all currently loaded subtypes
are included, including those not visible in the current module.

See also [`supertype`](@ref), [`supertypes`](@ref), [`methodswith`](@ref).

# Examples
```jldoctest
julia> subtypes(Integer)
3-element Vector{Any}:
 Bool
 Signed
 Unsigned
```
"""
subtypes(x::Type) = _subtypes_in!(Base.loaded_modules_array(), x)

"""
    supertypes(T::Type)

Return a tuple `(T, ..., Any)` of `T` and all its supertypes, as determined by
successive calls to the [`supertype`](@ref) function, listed in order of `<:`
and terminated by `Any`.

See also [`subtypes`](@ref).

# Examples
```jldoctest
julia> supertypes(Int)
(Int64, Signed, Integer, Real, Number, Any)
```
"""
function supertypes(T::Type)
    S = supertype(T)
    # note: we return a tuple here, not an Array as for subtypes, because in
    #       the future we could evaluate this function statically if desired.
    return S === T ? (T,) : (T, supertypes(S)...)
end

# TODO: @deprecate peakflops to LinearAlgebra
export peakflops
"""
    peakflops(n::Integer=4096; eltype::DataType=Float64, ntrials::Integer=3, parallel::Bool=false)

`peakflops` computes the peak flop rate of the computer by using double precision
[`gemm!`](@ref LinearAlgebra.BLAS.gemm!). For more information see
[`LinearAlgebra.peakflops`](@ref).

!!! compat "Julia 1.1"
    This function will be moved from `InteractiveUtils` to `LinearAlgebra` in the
    future. In Julia 1.1 and later it is available as `LinearAlgebra.peakflops`.
"""
function peakflops(n::Integer=4096; eltype::DataType=Float64, ntrials::Integer=3, parallel::Bool=false)
    # Base.depwarn("`peakflops` has moved to the LinearAlgebra module, " *
    #              "add `using LinearAlgebra` to your imports.", :peakflops)
    let LinearAlgebra = Base.require_stdlib(Base.PkgId(
            Base.UUID((0x37e2e46d_f89d_539d,0xb4ee_838fcccc9c8e)), "LinearAlgebra"))
        return LinearAlgebra.peakflops(n, eltype=eltype, ntrials=ntrials, parallel=parallel)
    end
end

function report_bug(kind)
    @info "Loading BugReporting package..."
    BugReportingId = Base.PkgId(
        Base.UUID((0xbcf9a6e7_4020_453c,0xb88e_690564246bb8)), "BugReporting")
    # Check if the BugReporting package exists in the current environment
    local BugReporting
    if Base.locate_package(BugReportingId) === nothing
        @info "Package `BugReporting` not found - attempting temporary installation"
        # Create a temporary environment and add BugReporting
        let Pkg = Base.require_stdlib(Base.PkgId(
            Base.UUID((0x44cfe95a_1eb2_52ea,0xb672_e2afdf69b78f)), "Pkg"))
            mktempdir() do tmp
                old_load_path = copy(LOAD_PATH)
                push!(empty!(LOAD_PATH), joinpath(tmp, "Project.toml"))
                old_active_project = Base.ACTIVE_PROJECT[]
                Base.ACTIVE_PROJECT[] = nothing
                pkgspec = @invokelatest Pkg.PackageSpec(BugReportingId.name, BugReportingId.uuid)
                @invokelatest Pkg.add(pkgspec)
                BugReporting = Base.require(BugReportingId)
                append!(empty!(LOAD_PATH), old_load_path)
                Base.ACTIVE_PROJECT[] = old_active_project
            end
        end
    else
        BugReporting = Base.require(BugReportingId)
    end
    return @invokelatest BugReporting.make_interactive_report(kind, ARGS)
end

end
