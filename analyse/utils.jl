function to_figure(e, t)
  e == "transfer" && return :transfer
  occursin(r"OP", t) && return :conflict
  :displacement
end
#
function smooth(xy)
  length(xy) ≤ 2 && return xy
  ts = [i for (i,v) in enumerate(xy) if !ismissing(v)]
  spl = ParametricSpline(ts, combinedimsview(collect(skipmissing(xy))); k = 2, s = 75)
  xy2 = [ismissing(xy[t]) ? missing : Point2f0(spl(t)) for t in 1:length(xy)]
end

timestep = 1/3

function filter_jump(rawcoords)
  xyts = StructArray(rawcoords)
  Δs = diff(xyts.t)
  i = findall(Δs .> 20) # find all the subsequent clicks that have more than 20 seconds in between them
  bad1 = [xyts.t[j]..xyts.t[j+1] for j in i]
  Δ = norm.(diff(xyts.xy))
  i = findall(Δ .> 20) # find all the subsequent clicks that have more than 20 cm in between them
  bad2 = [xyts.t[j]..xyts.t[j+1] for j in i]
  bad = [bad1; bad2]
  itp = interpolate((xyts.t, ), xyts.xy, Gridded(Linear()))
  ts = range(xyts.t[1], xyts.t[end], step = timestep)
  xy = Vector{Union{Missing, Point2f0}}(undef, length(ts))
  for (i, t) in enumerate(ts)
    if any(x -> t ∈ x, bad)
      xy[i] = missing
    else
      xy[i] = Point2f0(itp(t))
    end
  end
  smooth(xy)
end

to_treatment(x::String) = x == "FV"      ?  "Full vector" :
                        x == "ZV"      ?  "Zero vector" :
                        x == "FV_R"    ?  "Full vector (right)" :
                        x == "FV_L"    ?  "Full vector (left)" :
                        x == "ZV_R"    ?  "Zero vector (right)" :
                        x == "ZV_L"    ?  "Zero vector (left)" :
                        x == "OP-FV_R" ?  "Conflict full vector (right)" :
                        x == "OP-FV_L" ?  "Conflict full vector (left)" :
                        x == "HV"      ?  "Half vector" :
                        x

speed_interval = 6
max_speed = 30
speed_breaks = 0:speed_interval:max_speed
speed_mid = Int.(midpoints(speed_breaks))

#
# __getspeed(a1::Point2f0, a2::Point2f0) = norm(a2 - a1)
# __getspeed(a1, a2) = missing
# __getdistance(::Missing, c) = missing
# function __getdistance(a2, c)
#   L = norm(a2 - c)
#   i = Int(L ÷ speed_interval) + 1
# end
# function _getspeed(xy, c)
#   length(xy) ≤ 1 && return y
#   y = Vector{Union{Missing, Float64}}(missing, length(speed_mid))
#   o = DataFrame(s = Base.splat(__getspeed).(partition(xy, 2, 1)), l = __getdistance.(xy[1:end-1], Ref(c)))
#   dropmissing!(o)
#   for (i, g) in  pairs(groupby(o, :l))
#     y[i.l] = median(g.s)
#   end
#   return y
# end

# function _getspeed(xy, c)
#   o = [Median() for _ in speed_mid]
#   for (a1, a2) in partition(xy, 2, 1)
#     if !ismissing(a1) && !ismissing(a2)
#       L = norm(a2 - c)
#       i = Int(L ÷ speed_interval) + 1
#       Δ = norm(a2 - a1)
#       fit!(o[i], Δ)
#     end
#   end
#   [nobs(i) > 0 ? mean(i) : missing for i in o]
# end
#

import Base.-

-(::Missing, ::Point{2, Float32}) = missing
-(::Point{2, Float32}, ::Missing) = missing

function _getspeed(xy)
  y = Vector{Union{Missing, Float64}}(missing, length(speed_mid))
  n = length(xy)
  n ≤ 1 && return y
  # t = 1:n
  # @show xy
  # A = reduce(hcat, xy)'
  # itp = Interpolations.scale(interpolate(A, (BSpline(Cubic(Natural(OnGrid()))), NoInterp())), t, 1:2)
  # tfine = 1:.01:n
  # xy = [Point2f0(itp(fine, 1:2)) for fine in tfine]
  Δ = norm.(diff(xy))
  df = DataFrame(v = Δ ./ timestep, l = cumsum(Δ))
  @chain df begin
    dropmissing
    @subset :l .≤ max_speed
    @rtransform :bin = Int(:l ÷ speed_interval) + 1
    groupby(:bin)
    @combine :μv = mean(:v)
    @eachrow y[:bin] = :μv
  end
  return y
end

function get_speed(homing, searching)
  y1 = reverse(_getspeed(reverse(homing)))
  y2 = _getspeed(searching)
  y = [y1; y2]
  Impute.interp!(y)
  return y
end
#
function rm2small!(df, cutoff = 3)
  for g in groupby(df, [:figure, :treatment, :distance])
    if sum(completecases(g)) < cutoff
      g.speed .= missing
    end
  end
  df
end

function angle2tp(dropoff, tp)
  x, y = tp - dropoff
  α = 90 - atand(y, x)
  if α < 0
    α += 360
  end
  return α
end


# n = 100
# v = Float64.(collect(n:-1:1))
# v ./= sum(v)/30
# xy = accumulate((p, vi) -> p + Point2f0((vi + 0.03randn()) .* sincos(0.5rand())), v, init = zero(Point2f0))
# xy = allowmissing(xy)
# # xy[80:81] .= missing
# v1 = norm.(diff(xy))
# h = lines(-cumsum(v), v)
# lines!(-cumsum(v1), v1)
# s = _getspeed(reverse(xy))
# barplot!(-speed_mid, s)
# save("tmp.png", h)
#
# h = lines(xy, axis = (; aspect = DataAspect()))
# save("tmp.png", h)
