using Plots
using SpikingNeuralNetworks
SNN.@load_units
import SpikingNeuralNetworks: AdExParameter
using Statistics, Random


E = SNN.AdEx(; N = 2000, param = AdExParameter(; El = -40mV))
I = SNN.IF(; N = 500, param = SNN.IFParameter())
G = SNN.Rate(; N = 100)
EE = SNN.SpikingSynapse(E, E, :ge; σ = 10, p = 0.02)
EI = SNN.SpikingSynapse(E, I, :ge; σ = 40, p = 0.02)
IE = SNN.SpikingSynapse(I, E, :gi; σ = -50, p = 0.02)
II = SNN.SpikingSynapse(I, I, :gi; σ = -10, p = 0.02)
EG = SNN.SpikeRateSynapse(E, G; σ = 1.0, p = 0.02)
# GG = SNN.RateSynapse(G, G; σ = 1.2, p = 1.0)
P = [E, G, I]
C = [EE, EI, IE, II, EG, GG]
# C = [EE, EG, GG]

SNN.monitor([E, I], [:fire])
SNN.monitor(G, [(:r)])
SNN.sim!(P, C; duration = 4second)
SNN.raster([E, I], [3.4, 4] .* 10e3)
SNN.vecplot(G, :r, 10:20)

# Random.seed!(101)
# E = SNN.AdEx(;N = 100, param = AdExParameter(;El=-40mV))
# EE = SNN.SpikingSynapse(E, E, :ge; σ=10, p = 0.02)
# EG = SNN.SpikeRateSynapse(E, G; σ = 1., p = 1.0)
# SNN.monitor(E, [:fire])
# SNN.sim!(P, C; duration = 4second)
# SNN.raster([E], [900, 1000])
# plot!(xlims=(100,1000))