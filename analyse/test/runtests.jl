using Test, StatsBase, CairoMakie, LinearAlgebra
import CairoMakie: Point2f0

include(joinpath("..", "utils.jl"))

_expected = Dict(
                (0,1) => 0,
                (1,1) => 45,
                (1,0) => 90,
                (1,-1) => 135,
                (0,-1) => 180,
                (-1,-1) => 225,
                (-1,0) => 270,
                (-1,1) => 315
               )
expected = Dict(normalize(Point2f0(k)) => v for (k,v) in _expected)
dropoff = zero(Point2f0)

# figure 
f = Figure(resolution = (600,600))
ax = Axis(f[1, 1], aspect = DataAspect())
text!(ax, "dropoff", position = dropoff, align = (:center, :center))
ps = collect(keys(expected))
text!(ax, string.(values(expected), "°"), position = ps, align = (:center, :center))
arrows!(ax, 0.2ps, 0.6ps)
hidedecorations!(ax)
hidespines!(ax)
save("angle_test.png", f)

# test
@testset "angles" begin
  for (tp, α) in expected
    @test angle2tp(dropoff, tp + dropoff) ≈ α
  end
end


