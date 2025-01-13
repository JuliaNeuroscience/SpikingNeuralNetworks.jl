@snn_kw struct BalancedStimulusParameter{VFT}
    kIE::Float32 = 1.0
    β::Float32 = 0.0
    τ::Float32 = 50.0
    r0::Float32 = 1kHz
    wIE::Float32 = 1.0
    same_input::Bool = false
end

BSParam = BalancedStimulusParameter

@snn_kw struct BalancedStimulus{VFT = Vector{Float32},VBT = Vector{Bool},VIT = Vector{Int}, IT = Int32} <: AbstractStimulus
    id::String = randstring(12)
    param::BalancedStimulusParameter
    name::String = "Balanced"
    N::IT = 100
    N_pre::IT = 5
    cells::VIT
    ##
    ge::VFT # target conductance for exc
    gi::VFT # target conductance for inh
    colptr::VIT
    rowptr::VIT
    I::VIT
    J::VIT
    index::VIT
    r::VFT
    noise::VFT
    W::VFT
    fire::VBT = zeros(Bool, N_pre)
    ##
    randcache::VFT = rand(N_pre) # random cache
    randcache_β::VFT = rand(N) # random cache
    records::Dict = Dict()
    targets::Dict = Dict()
end


"""
    BalancedStimulus(post::T, sym::Symbol, r::Union{Function, Float32}, cells=[]; N_pre::Int=50, p_post::R=0.05f0, μ::R=1.f0, param=BalancedParameter()) where {T <: AbstractPopulation, R <: Number}

Constructs a BalancedStimulus object for a spiking neural network.

# Arguments
- `post::T`: The target population for the stimulus.
- `sym::Symbol`: The symbol representing the synaptic conductance or current.
- `r::Union{Function, Float32}`: The firing rate of the stimulus. Can be a constant value or a function of time.
- `cells=[]`: The indices of the cells in the target population that receive the stimulus. If empty, cells are randomly selected based on the probability `p_post`.
- `N::Int=200`: The number of Balanced neurons cells.
- `N_pre::Int=5`: The number of presynaptic connected.
- `p_post::R=0.05f0`: The probability of connection between presynaptic and postsynaptic cells.
- `μ::R=1.f0`: The scaling factor for the synaptic weights.
- `param=BalancedParameter()`: The parameters for the Balanced distribution.

# Returns
A `BalancedStimulus` object.
"""
function BalancedStimulus(post::T, sym_e::Symbol, sym_i::Symbol, target = nothing; cells=[], μ=1.f0, param::Union{BalancedStimulusParameter,R}, kwargs...) where {T <: AbstractPopulation, R <: Real}

    cells = 1:post.N
    w = zeros(Float32, length(cells), length(cells))
    w = μ* sparse(w)
    rowptr, colptr, I, J, index, W = dsparse(w)

    if isnothing(target) 
        ge = getfield(post, sym_e)
        gi = getfield(post, sym_i)
        targets = Dict(:pre => :Balanced, :g => post.id, :sym=>:soma)
    elseif typeof(target) == Symbol
        ge = getfield(post, Symbol("$(sym_e)_$target"))
        gi = getfield(post, Symbol("$(sym_i)_$target"))
        targets = Dict(:pre => :Balanced, :g => post.id, :sym=>target)
    elseif typeof(target) == Int
        sym_i= Symbol("$(sym_i)_d")
        sym_e= Symbol("$(sym_e)_d")
        ge = getfield(post, sym_e)[target]
        gi = getfield(post, sym_i)[target]
        targets = Dict(:pre => :Balanced, :g => post.id, :sym=>Symbol(string(sym_e, target)))
    end

    # if isnothing(target) 
    #     ge = getfield(post, sym_e)
    #     gi = getfield(post, sym_i)
    # else
    #     ge = getfield(post, Symbol("$(sym_e)_$target"))
    #     gi = getfield(post, Symbol("$(sym_i)_$target"))
    # end


    if typeof(param) <: Real
        r = param
        param = BSParam(rate = (x,y)->r, r* param.kIE)
    end

    r= ones(Float32, post.N)*param.r0
    noise = zeros(Float32, post.N)

    N_pre = ceil(Int, param.r0 * maximum([1, param.β/100]) )

    # Construct the SpikingSynapse instance
    return BalancedStimulus(;
        param = param,
        N = length(cells),
        N_pre = N_pre,
        cells = cells,
        targets = targets,
        r = r,
        noise = noise,
        ge = ge,
        gi = gi,
        @symdict(rowptr, colptr, I, J, index, W)...,
        kwargs...,
    )
end


"""
    stimulate!(p::BalancedStimulus, param::BalancedParameter, time::Time, dt::Float32)

Generate a Balanced stimulus for a postsynaptic population.
"""
function stimulate!(p::BalancedStimulus, param::BalancedStimulusParameter, time::Time, dt::Float32)
    @unpack N, N_pre, randcache, randcache_β, fire, cells, colptr, W, I, ge, gi = p

    ## Inhomogeneous Poisson process
    @unpack r0, β, τ, kIE, wIE, same_input = param
    @unpack noise, r = p
    # Irate::Float32 = r0 * kIE
    R(x::Float32, v0::Float32=0.f0) = x > 0.f0 ? x : v0

    # Inhibitory spike
    rand!(randcache)
    for i in 1:N
        @simd for j = 1:N_pre # loop on presynaptic cells
            if randcache[j] < r0*kIE/N_pre * dt 
                gi[i] += 1 * wIE
            end
        end
    end

    # Excitatory spike
    re::Float32 = 0.f0
    cc::Float32 = 0.f0
    Erate::Float32 = 0.f0
    rand!(randcache_β)
    rand!(randcache)
    if same_input
        i = 1
        re= randcache_β[i] - 0.5f0
        cc = 1.0f0 - dt / τ
        noise[i] = ( noise[i] - re) * cc + re
        Erate = R(r0./2 *  R(noise[i] * β, 1.f0) + r[i], 0.f0) 
        r[i] += (r0 - Erate)/400ms * dt
        @assert Erate >= 0
        @inbounds @fastmath for i = 1:N
            @simd for j in 1:N_pre # loop on presynaptic cells
                if randcache[j] < Erate/N_pre * dt 
                    ge[i] += 1.
                end
            end
        end
    else
        @inbounds @fastmath for i = 1:N
            re= randcache_β[i] - 0.5f0
            cc = 1.0f0 - dt / τ
            noise[i] = ( noise[i] - re) * cc + re
            Erate = R(r0./2 *  R(noise[i] * β, 1.f0) + r[i], 0.f0) 
            r[i] += (r0 - Erate)/400ms * dt
            @assert Erate >= 0
            @simd for j in 1:N_pre # loop on presynaptic cells
                if randcache[j] < Erate/N_pre * dt 
                    ge[i] += 1.
                end
            end
        end
    end

end

export BalancedStimuli, stimulate!, BSParam, BalancedStimulusParameter
