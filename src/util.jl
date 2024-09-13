function connect!(c, j, i, σ = 1e-6)
    W = sparse(c.I, c.J, c.W, length(c.rowptr) - 1, length(c.colptr) - 1)
    W[i, j] = σ * randn(Float32)
    c.rowptr, c.colptr, c.I, c.J, c.index, c.W = dsparse(W)
    c.tpre, c.tpost, c.Apre, c.Apost = zero(c.W), zero(c.W), zero(c.W), zero(c.W)
    return nothing
end


# """function dsparse

function dsparse(A)
    # them in a special data structure leads to savings in space and execution time, compared to dense arrays.
    At = sparse(A') # Transposes the input sparse matrix A and stores it as At.
    colptr = A.colptr # Retrieves the column pointer array from matrix A
    rowptr = At.colptr # Retrieves the column pointer array from the transposed matrix At
    I = rowvals(A) # Retrieves the row indices of non-zero elements from matrix A
    V = nonzeros(A) # Retrieves the values of non-zero elements from matrix A
    J = zero(I) # Initializes an array J of the same size as I filled with zeros.
    index = zeros(Int, size(I)) # Initializes an array index of the same size as I filled with zeros.


    # FIXME: Breaks when A is empty
    for j = 1:(length(colptr)-1) # Starts a loop iterating through the columns of the matrix.
        J[colptr[j]:(colptr[j+1]-1)] .= j # Assigns column indices to J for each element in the column range.
    end
    coldown = zeros(eltype(index), length(colptr) - 1) # Initializes an array coldown with a specific type and size.
    for i = 1:(length(rowptr)-1) # Iterates through the rows of the transposed matrix At.
        for st = rowptr[i]:(rowptr[i+1]-1) # Iterates through the range of elements in the current row.
            j = At.rowval[st] # Retrieves the column index from the transposed matrix At.
            index[st] = colptr[j] + coldown[j] # Computes an index for the index array.
            coldown[j] += 1 # Updates coldown for indexing.
        end
    end
    # Test.@test At.nzval == A.nzval[index]
    rowptr, colptr, I, J, index, V # Returns the modified rowptr, colptr, I, J, index, and V arrays.
end

function record!(obj)
    """
    Store values into the dictionary named `records` in the object given 

    # Arguments
    - `obj`: An object whose values are to be recorded

    """
    for (key, val) in obj.records
        # `val` here is a vector, so we can directly push a value from the variable accessed with getfield(obj, key) into this vector
        (key == :indices) && (continue)
        if haskey(obj.records, :indices) && haskey(obj.records[:indices], key)
            indices = get(obj.records, :indices, nothing)
            ind = get(indices, key, nothing)
            push!(val, getindex(getfield(obj, key), ind)) # getindex returns the subset of `getfield(obj, sym)` at the given index `ind`
        else
            # copy() is necessary here because we want to push the same value but store it at a different memory location (so that when one is changed, the other is not)
            push!(val, copy(getfield(obj, key)))
        end
    end
end

function monitor(obj, keys)
    """
    Initialize dictionary records for the given object, by assigning empty vectors to the given keys

    # Arguments
    - `obj`: An object whose variables will be monitored
    - `keys`: The variables to be monitored

    """
    for key in keys
        # @info key
        if isa(key, Tuple)
            sym, ind = key
            if !haskey(obj.records, :indices)
                obj.records[:indices] = Dict{Symbol,Vector{Int}}()
            end
            push!(obj.records[:indices], sym => ind)
        else
            sym = key
        end
        typ = typeof(getfield(obj, sym))
        obj.records[sym] = Vector{typ}()
    end
end

function monitor(objs::Array, keys)
    """
    Function called when more than one object is given, which then calls the above monitor function for each object
    """
    for obj in objs
        monitor(obj, keys)
    end
end

function getrecord(p, sym)
    key = sym
    for (k, val) in p.records
        isa(k, Tuple) && k[1] == sym && (key = k)
    end
    p.records[key]
end

function clear_records(obj)
    for (key, val) in obj.records
        key == :indices && continue
        empty!(val)
    end
end

function clear_records(obj, sym::Symbol)
    for (key, val) in obj.records
        (key == sym) && (empty!(val))
    end
end

function clear_records(objs::AbstractArray)
    for obj in objs
        clear_records(obj)
    end
end

function clear_monitor(obj)
    for (k, val) in obj.records
        delete!(obj.records, k)
    end
end

@inline function exp32(x::Float32)
    x = ifelse(x < -10.0f0, -32.0f0, x)
    x = 1.0f0 + x / 32.0f0
    x *= x
    x *= x
    x *= x
    x *= x
    x *= x
    return x
end

@inline function exp256(x::Float32)
    x = ifelse(x < -10.0f0, -256.0f0, x)
    x = 1.0f0 + x / 256.0f0
    x *= x
    x *= x
    x *= x
    x *= x
    x *= x
    x *= x
    x *= x
    x *= x
    return x
end

macro symdict(x...)
    ex = Expr(:block)
    push!(ex.args, :(d = Dict{Symbol,Any}()))
    for p in x
        push!(ex.args, :(d[$(QuoteNode(p))] = $(esc(p))))
    end
    push!(ex.args, :(d))
    return ex
end

snn_kw_str_param(x::Symbol) = (x,)
function snn_kw_str_param(x::Expr)
    if x.head == :(<:)
        return (x.args...,)
    elseif x.head == :(=)
        if x.args[1] isa Expr && x.args[1].head == :(<:)
            return (x.args[1].args..., x.args[2])
        elseif x.args[1] isa Symbol
            return (x.args[1], Any, x.args[2])
        end
    end
    error("Can't handle param Expr: $x")
end
snn_kw_str_field(x::Symbol) = (x,)
function snn_kw_str_field(x::Expr)
    if x.head == :(::)
        return (x.args...,)
    elseif x.head == :(=)
        return (x.args[1].args[1:2]..., x.args[2])
    end
    error("Can't handle field Expr: $x")
end
function snn_kw_str_kws(x::Tuple)
    if 1 <= length(x) <= 2
        return x[1]
    elseif length(x) == 3
        return Expr(:kw, x[1], x[3])
    end
end
function snn_kw_str_kws_types(x::Tuple)
    if 1 <= length(x) <= 2
        return Expr(:(::), x[1], x[2])
    elseif length(x) == 3
        return Expr(:kw, x[1], x[3])
    end
end
struct KwStrSentinel end
function snn_kw_str_sentinels(x)
    if length(x) == 1
        return (x[1], Any, :(KwStrSentinel()))
    elseif length(x) == 2
        return (x[1], Any, :(KwStrSentinel()))
    else
        return x
    end
end
snn_kw_str_sentinel_check(x) = :(
    if $(x[1]) isa KwStrSentinel
        $(x[1]) = $(length(x) > 1 ? x[2] : Any)
    end
)
"A minimal implementation of `Base.@kwdef` with default type parameter support"
macro snn_kw(str)
    str_abs = nothing
    if str.args[2] isa Expr && str.args[2].head == :(<:)
        # Lower abstract type
        str_abs = str.args[2].args[2]
        str.args[2] = str.args[2].args[1]
    end
    if str.args[2] isa Symbol
        # No type params
        str_name = str.args[2]
        str_params = []
    else
        # Has type params
        str_name = str.args[2].args[1]
        str_params = map(snn_kw_str_param, str.args[2].args[2:end])
    end
    @assert str_name isa Symbol
    @assert str_abs isa Union{Symbol,Nothing}
    str_fields =
        map(snn_kw_str_field, filter(x -> !(x isa LineNumberNode), str.args[3].args))

    # Remove default type params
    if length(str_params) > 0
        idx = 1
        for idx = 2:length(str.args[2].args)
            param = str_params[idx-1]
            if length(param) == 1
                str.args[2].args[idx] = param[1]
            else
                str.args[2].args[idx] = Expr(:(<:), param[1:2]...)
            end
        end
    end

    # Remove default field values
    idx = 1
    subidx = 1
    for idx = 1:length(str.args[3].args)
        if !(str.args[3].args[idx] isa LineNumberNode)
            field = str_fields[subidx]
            if length(field) == 1
                str.args[3].args[idx] = field[1]
            else
                str.args[3].args[idx] = Expr(:(::), field[1:2]...)
            end
            subidx += 1
        end
    end

    # Replace abstract type
    if str_abs !== nothing
        str.args[2] = Expr(:(<:), str.args[2], str_abs)
    end

    # Use sentinels to track if type param kwargs are assigned
    ctor_params = snn_kw_str_sentinels.(str_params)
    ctor_params_bodies = snn_kw_str_sentinel_check.(str_params)

    # Constructor accepts field values and type params as kwargs
    ctor_kws = Expr(
        :parameters,
        map(snn_kw_str_kws, str_fields)...,
        map(snn_kw_str_kws_types, ctor_params)...,
    )
    ctor_sig = Expr(:call, str_name, ctor_kws)
    ctor_call = if length(str_params) > 0
        Expr(:curly, str_name, first.(str_params)...)
    else
        str_name
    end
    ctor_body =
        Expr(:block, ctor_params_bodies..., Expr(:call, ctor_call, first.(str_fields)...))
    ctor = Expr(:function, ctor_sig, ctor_body)

    return quote
        $(esc(str))
        $(esc(ctor))
    end
end