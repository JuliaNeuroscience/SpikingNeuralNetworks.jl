const metre = 1e2
const meter = metre
const cm = metre / 1e2
const mm = metre / 1e3
const um = metre / 1e6
const nm = metre / 1e9

const second = 1e3
const s = second
const ms = second / 1e3
const Hz = 1 / second
const kHz = Hz * 1e3

const voltage = 1e3
const mV = voltage / 1e3

const ampere = 1e12
const mA = ampere / 1e3
const uA = ampere / 1e6
const μA = ampere / 1e6
const nA = ampere / 1e9
const pA = ampere / 1e12

const farad = 1e12
const mF = farad / 1e3
const uF = farad / 1e6
const μF = farad / 1e6
const nF = farad / 1e9
const pF = farad / 1e12
const ufarad = uF

const siemens = 1e9
const mS = siemens / 1e3
const msiemens = mS
const nS = siemens / 1e9
const nsiemens = nS

const Ω = 1 / siemens
const MΩ = Ω * 1e6
const GΩ = Ω * 1e9

second / Ω ≈ farad

@assert second / Ω ≈ farad
@assert Ω * siemens ≈ 1
@assert Ω * ampere ≈ voltage
@assert ampere * second / voltage == farad

macro load_units()
    exs = map((
        :metre,
        :Hz,
        :kHz,
        :meter,
        :cm,
        :mm,
        :um,
        :nm,
        :second,
        :s,
        :ms,
        :Hz,
        :voltage,
        :mV,
        :ampere,
        :mA,
        :uA,
        :μA,
        :nA,
        :pA,
        :farad,
        :Ω,
        :uF,
        :μF,
        :pF,
        :ufarad,
        :siemens,
        :mS,
        :msiemens,
        :nS,
        :nsiemens,
    )) do s
        :($s = getfield($@__MODULE__, $(QuoteNode(s))))
    end
    ex = Expr(:block, exs...)
    esc(ex)
end
