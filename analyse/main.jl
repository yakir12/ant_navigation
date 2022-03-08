import Pkg
Pkg.activate(".")
Pkg.instantiate()

# packages we're using
using LazyArtifacts

using Arrow, DataFramesMeta, CairoMakie, Statistics, LinearAlgebra, CSV, Dates, Chain, Colors, Missings, StructArrays, IntervalSets, Interpolations, Dierckx, StatsBase, DataFramesMeta, SplitApplyCombine, Impute, Distributions
import IterTools:partition
import CairoMakie: Point2f0

include("plots.jl") # plotting functions
include("utils.jl") # some utility functions

results = joinpath("..", "results") # name of the folder where all the results will get saved
mkpath(results)
tbl = artifact"db.arrow/db.arrow"
df = @chain tbl begin
  Arrow.Table # transform to an arrow table
  DataFrame # transform to a dataframe
  transform([:dropoff, :fictive_nest, :nest, :feeder] .=> ByRow(passmissing(Point2)), renamecols = false)
  @rtransform(
              :tp = ceil(Int, (:t[:tp] - :t[1])/timestep),
              :coords = filter_jump(:rawcoords),
              :figure = to_figure(:Experiment, :treatment),
              :treatment = to_treatment(:treatment)
             )
  @rtransform(
              :homing = :coords[1 : :tp],
              :turning_point = :coords[:tp],
              :searching = :coords[:tp:end],
              # :point10 = find10(:coords)
             )
  @rtransform(
              $"angle to YP" = angle2tp(:dropoff, :turning_point),
              $"center of search" = mean(skipmissing(:searching))
             )
end

# save results file
@chain df begin
  select(Not(Cols(["feeder to nest", "pellets", "coords", "t", "tp", "rawcoords", "figure", "homing", "searching"])))
  transform(_, names(_, Point) .=> ByRow(passmissing(Tuple)), renamecols = false)
  CSV.write(joinpath(results, "results.csv"), _)
end

# plot tracks
colors = distinguishable_colors(length(unique(df.figure)), [colorant"white", colorant"black"], dropseed = true)
for ((k, gd), color) in zip(pairs(groupby(df, :figure, sort = true)), colors)
  fig = plottracks(gd; color)
  save(joinpath(results, string("track ", k..., ".pdf")), fig)
end

# plot TP and center of search
for ((k, gd), color) in zip(pairs(groupby(df, :figure, sort = true)), colors), what in ("center of search", "turning_point")
  fig = plotpoints(gd, what; color)
  save(joinpath(results, string("$what ", k..., ".pdf")), fig)
end

# speed analysis
dd = @chain df begin
  select([:homing, :searching] => ByRow(get_speed) => ["$i" for i in [-reverse(speed_mid); speed_mid]], :figure, :treatment, :ID)
end

Mx = max_speed
My = maximum(skipmissing(Matrix(select(dd, Not(Cols(:figure, :treatment, :ID))))))

dd = @chain dd begin
  @aside begin
    CSV.write(joinpath(results, "speeds.csv"), _)
  end
  stack(Not(Cols(:figure, :treatment, :ID)), variable_name=:distance, value_name=:speed)
  transform(:distance => x -> parse.(Int, x); renamecols = false)
  @aside begin
    for ((k, gd), color) in zip(pairs(groupby(_, :figure, sort = true)), colors)
      fig = plotindividualspeeds(gd, Mx, My; color)
      save(joinpath(results, string("individual speed ", k..., ".pdf")), fig)
    end
  end
  # rm2small!
  dropmissing!
end

# plot speeds
# Mx = maximum(abs, dd.distance) + speed_interval
# My = maximum(dd.speed)
for ((k, gd), color) in zip(pairs(groupby(dd, :figure, sort = true)), colors)
  fig = plotspeeds(gd, Mx, My; color)
  save(joinpath(results, string("speed ", k..., ".pdf")), fig)
end



# dd = @chain df begin
#   select([:homing, :searching] => ByRow(get_speed) => ["$i" for i in [-reverse(speed_mid); speed_mid]], :figure, :treatment, :ID)
# end
#

