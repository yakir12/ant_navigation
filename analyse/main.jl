import Pkg
Pkg.activate(".")
Pkg.instantiate()

# packages we're using
using LazyArtifacts

using Arrow, DataFrames, CairoMakie, Statistics, LinearAlgebra, CSV, Dates, Chain, Colors, Missings, StructArrays, IntervalSets, Interpolations, Dierckx, StatsBase
import IterTools:partition
import CairoMakie: Point2f0

# const conf = ConfParse("configuration.ini")
# parse_conf!(conf)

include("plots.jl") # plotting functions
include("utils.jl") # some utility functions

results = joinpath("..", "results") # name of the folder where all the results will get saved
mkpath(results)
link = artifact"db.arrow/db.arrow"
df = @chain link begin
  Arrow.Table # transform to an arrow table
  DataFrame # transform to a dataframe
  transform(
            [:dropoff, :fictive_nest, :nest, :feeder] .=> ByRow(passmissing(Point2)) .=> [:dropoff, :fictive_nest, :nest, :feeder],
            [:t, :tp] => ByRow((t, tp) -> ceil(Int, t[tp] - t[1])) => :tp,
            :rawcoords => ByRow(filter_jump) => :coords,
            # :coords => ByRow(x -> Point2f0.(x)) => :coords,
            [:Experiment, :treatment] => ByRow(to_figure) => :figure, # what figure
            :treatment => ByRow(treatments) => :treatment
           )
  transform(
            [:coords, :tp] => ByRow((xy, i) -> xy[1:i]) => :homing, # the homing part of the track
            [:coords, :tp] => ByRow((xy, i) -> xy[i:end]) => :searching, # the homing part of the track
            [:coords, :tp] => ByRow((xy, i) -> xy[i]) => :turning_point # add the turning point
           )
  transform(
            [:turning_point, :dropoff] => ByRow(angle2tp) => "angle to TP",
            :searching => ByRow(mean ∘ skipmissing) => "center of search",
           )
  # filter(:homing => >(1)∘length, _) # remove runs where the homing section is just one point
  # filter(:searching => >(1)∘length, _)
  @aside @chain _ begin
    select(Not(Cols(["feeder to nest", "pellets", "coords", "t", "tp", "rawcoords", "figure", "homing", "searching"])))
    transform([:dropoff, :fictive_nest, :nest, :feeder] .=> ByRow(passmissing(Tuple)) .=> [:dropoff, :fictive_nest, :nest, :feeder])
    CSV.write(joinpath(results, "results.csv"), _)
  end 
end

CSV.write(joinpath(results, "results.csv"), select(df, Not(Cols(["feeder to nest", "pellets", "coords", "t", "tp", "rawcoords", "figure", "homing", "searching"]));) ; transform = (col, val) -> val isa Point2 ? Tuple(val) : val)

# plot tracks
colors = distinguishable_colors(length(unique(df.figure)), [colorant"white", colorant"black"], dropseed = true)
for ((k, gd), color) in zip(pairs(groupby(df, :figure, sort = true)), colors)
  fig = plottracks(gd; color)
  save(joinpath(results, string("track ", k..., ".pdf")), fig)
end

# speed analysis
dd = @chain df begin
  select([:homing, :turning_point, :searching] => ByRow(get_speed) => ["$i" for i in [-reverse(speed_mid); speed_mid]], :figure, :treatment)
  @aside CSV.write(joinpath(results, "speeds.csv"), _)
  stack(Not(Cols(:figure, :treatment)), variable_name=:distance, value_name=:speed)
  rm2small!
  dropmissing!
  transform(:distance => x -> parse.(Int, x); renamecols = false)
end

# plot speeds
Mx = maximum(abs, dd.distance) + speed_interval
My = maximum(dd.speed)
for ((k, gd), color) in zip(pairs(groupby(dd, :figure, sort = true)), colors)
  fig = plotspeeds(gd, Mx, My; color)
  save(joinpath(results, string("speed ", k..., ".pdf")), fig)
end
