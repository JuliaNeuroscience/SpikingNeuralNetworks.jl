using .Plots, Statistics

## Raster plot

function raster_populations(p, interval = nothing; populations::Vector{T}) where T <: AbstractVector
    all_spiketimes = spiketimes(p)
    y0 = 0
    x, y = Float32[], Float32[]
    pop_boundaries = []  # To store the boundary positions for each population

    for pop in populations
        push!(pop_boundaries, y0)  # Store the starting y0 for each population
        spiketimes_pop = all_spiketimes[pop]  # Population spiketimes
        for n in eachindex(spiketimes_pop)  # Neuron spiketimes
            for t in spiketimes_pop[n]  # Spiketime
                if isnothing(interval) || (t > interval[1] && t < interval[2])
                    push!(x, t)
                    push!(y, n + y0)
                end
            end
        end
        y0 += length(spiketimes_pop)
    end

    # Add the final boundary for the last population
    push!(pop_boundaries, y0)

    return x, y, pop_boundaries
end




function raster(p, interval = nothing)
    fire = p.records[:fire]
    x, y = Float32[], Float32[]
    # which time to plot
    for i in eachindex(fire[:time])
    t = fire[:time][i]
    # which neurons to plot
        for n in fire[:neurons][i]
            if isnothing(interval) || (t > interval[1] && t < interval[2])
                push!(x, t)
                push!(y, n)
            end
        end
    end
    return x, y
end


function raster(P::Array, t = nothing, dt = 0.1ms; populations = nothing, population_labels = nothing, kwargs...)
    y0 = Int32[0]
    X = Float32[]
    Y = Float32[]
    boundaries = []  # To store all population boundaries
    label_positions = []  # To store the y positions for labels

    for p in P
        if isnothing(populations)
            x, y = raster(p, t; kwargs...)
        else
            x, y, pop_boundaries = raster_populations(p, t; populations = populations, kwargs...)
            # Adjust the boundaries to the current y0 and collect them
            adjusted_boundaries = [b + sum(y0) for b in pop_boundaries]
            append!(boundaries, adjusted_boundaries)
            
            # Determine the y position for labels (midpoint of each population)
            for j in 1:(length(adjusted_boundaries) - 1)
                push!(label_positions, (adjusted_boundaries[j] + adjusted_boundaries[j + 1]) / 2)
            end
        end

        append!(X, x)
        append!(Y, y .+ sum(y0))
        push!(y0, p.N)
    end

    # Add label for the last population (use the midpoint of the last population)
    if !isempty(boundaries)
        last_midpoint = (boundaries[end-1] + boundaries[end]) / 2
        push!(label_positions, last_midpoint)
    end

    # Create y-axis labels based on the population labels
    yticks = nothing
    if !isnothing(population_labels) && !isempty(label_positions)
        yticks = (label_positions, population_labels)
    end

    # Plot the scatter
    plt = scatter(
        X,
        Y,
        m = (1, :black),
        leg = :none,
        xaxis = ("t", (0, Inf)),
        yaxis = !isnothing(population_labels) ? ("stimuli",) : ("neuron",),
        yticks = yticks  # Add y-axis labels here
    )

    # Plot red lines between populations
    !isempty(boundaries) && hline!(plt, boundaries[2:end], linecolor = :red)

    # Plot boundaries for populations in y0
    y0 = y0[2:(end-1)]
    !isempty(y0) && hline!(plt, cumsum(y0), linecolor = :red)
    !isnothing(t) && plot!(xlims = t)

    return plt
end



## Vector plot

function vecplot(p, sym; kwargs...)
    vecplot!(plot(), p, sym; kwargs...)
end

function vecplot(P::Array, sym; kwargs...)
    plts = [vecplot(p, sym; kwargs...) for p in P]
    N = length(plts)
    plot(plts..., size = (600, 400N), layout = (N, 1))
end

function vecplot!(
    my_plot,
    p,
    sym;
    neurons = nothing,
    pop_average = false,
    r::AbstractArray{T} = 0:-1,
    dt = 0.1,
    sym_id = nothing,
    factor = 1,
    kwargs...,
) where {T<:Real}
    # get steps of the interval from dt and remove first and last step
    r_dt =  r[2:(end-1)] |> r-> round.(Int, r ./ dt)[1:(end-1)]
    # get the record
    v = getrecord(p, sym)
    # check if the record is a vector or a matrix
    if isa(v[1], Vector)
        # if the record is a vector
        _time=size(v, 1)
        _n = size(v[1], 1)
        y = zeros(_time, _n)
        neurons = isnothing(neurons) ? _n : neurons
        for i in 1:_time
            y[i, :] = v[i]*factor
        end
        y = y[r_dt, neurons]
        y = pop_average ? mean(y, dims = 2)[:, 1] : y
    elseif isa(v[1], Matrix)
        _time=size(v, 1)
        _n = size(v[1], 1)
        _x = size(v[1], 2)
        y = zeros(_time, _n, _x)
        neurons = isnothing(neurons) ? _n : neurons
        for i in 1:_time
            y[i, :, :] = v[i]*factor
        end
        isnothing(sym_id) && (throw(ArgumentError("The record is a matrix, please specify the index of the matrix to plot")))
        y = y[r_dt, neurons, sym_id]
        y = pop_average ? mean(y, dims = 2)[:, 1, :] : y
    else
        throw(ArgumentError("The record is not a vector or a matrix"))
    end

    x = r_dt .* dt
    plot!(
        my_plot,
        x,
        y,
        leg = :none,
        xaxis = ("t", extrema(x)),
        yaxis = (string(sym), extrema(y));
        kwargs...,
    )
end


# function vecplot!(P::Array, sym; kwargs...)
#     plts = [vecplot(p, sym; kwargs...) for p in P]
#     my_plot = plot()
#     for p in P
#         vecplot!(my_plot, p, sym; kwargs...)
#     end
#     plot!(my_plot; kwargs...)
#     return my_plot
# end

function vecplot(P, syms::Array; kwargs...)
    plts = [vecplot(P, sym; kwargs...) for sym in syms]
    N = length(plts)
    plot(plts..., size = (600, 400N), layout = (N, 1))
end

## Matrix plot

## Rateplot

function rateplot(p, sym)
    r = getrecord(p, sym)
    R = hcat(r...)
end

function rateplot(P::Array, sym)
    R = vcat([rateplot(p, sym) for p in P]...)
    y0 = [p.N for p in P][2:(end-1)]
    plt = heatmap(R, leg = :none)
    !isempty(y0) && hline!(plt, cumsum(y0), line = (:black, 1))
    plt
end


function if_curve(model, current; neuron = 1, dt = 0.1ms, duration = 1second)
    E = model(neuron)
    monitor(E, [:fire])
    f = Float32[]
    for I in current
        clear_records(E)
        E.I = [I]
        SNN.sim!([E], []; dt = dt, duration = duration)
        push!(f, activity(E))
    end
    plot(current, f)
end

# export density
# function density(p, sym)
#   X = getrecord(p, sym)
#   t = dt*(1:length(X))
#   xmin, xmax = extrema(vcat(X...))
#   edge = linspace(xmin, xmax, 100)
#   c = center(edge)
#   ρ = [fit(Histogram, x, edge).weights |> reverse |> float for x in X] |> x->hcat(x...)
#   ρ = smooth(ρ, windowsize(p), 2)
#   ρ ./= sum(ρ, 1)
#   surface(t, c, ρ, ylabel="p")
# end
# function density(P::Array, sym)
#   plts = [density(p, sym) for p in P]
#   plot(plts..., layout=(length(plts),1))
# end


# function windowsize(p)
#     A = sum.(p.records[:fire]) / length(p.N)
#     W = round(Int32, 0.5p.N / mean(A)) # filter window, unit=1
# end

# function density(p, sym)
#     X = getrecord(p, sym)
#     t = 1:length(X)
#     xmin, xmax = extrema(vcat(X...))
#     edge = linspace(xmin, xmax, 50)
#     c = center(edge)
#     ρ = [fit(Histogram, x, edge).weights |> float for x in X] |> x -> hcat(x...)
#     ρ = smooth(ρ, windowsize(p), 2)
#     ρ ./= sum(ρ, 1)
#     p = @gif for t = 1:length(X)
#         bar(c, ρ[:, t], leg = false, xlabel = string(sym), yaxis = ("p", extrema(ρ)))
#     end
#     is_windows() && run(`powershell start $(p.filename)`)
#     is_unix() && run(`xdg-open $(p.filename)`)
#     p
# end

# function activity(p)
#     A = sum.(p.records[:fire]) / length(p.N)
#     W = windowsize(p)
#     A = smooth(A, W)
# end

# function activity(P::Array)
#     A = activity.(P)
#     t = 1:length(P[1].records[:fire])
#     plot(t, A, leg = :none, xaxis = ("t",), yaxis = ("A", (0, Inf)))
# end
