function to_figure(e, t)
  e == "transfer" && return :transfer
  occursin(r"OP", t) && return :conflict
  :displacement
end
#
function smooth(xy)
  length(xy) ≤ 2 && return xy
  ts = [i for (i,v) in enumerate(xy) if !ismissing(v)]
  spl = ParametricSpline(ts, reduce(hcat, skipmissing(xy)); k = 2, s = 75)
  xy2 = [ismissing(xy[t]) ? missing : Point2f0(spl(t)) for t in 1:length(xy)]
  # xy2[1] = xy[1]
  # xy2[end] = xy[end]
  # xy2
end

function filter_jump(rawcoords)
  xyts = StructArray(rawcoords)
  Δs = diff(xyts.t)
  i = findall(Δs .> 20) # minimum of 20
  bad = [xyts.t[j]..xyts.t[j+1] for j in i]
  itp = interpolate((xyts.t, ), xyts.xy, Gridded(Linear()))
  ts = range(xyts.t[1], xyts.t[end], step = 1)
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

treatments(x::String) = x == "FV"      ?  "Full vector" :
                        x == "ZV"      ?  "Zero vector" :
                        x == "FV_R"    ?  "Full vector (right)" :
                        x == "FV_L"    ?  "Full vector (left)" :
                        x == "ZV_R"    ?  "Zero vector (right)" :
                        x == "ZV_L"    ?  "Zero vector (left)" :
                        x == "OP-FV_R" ?  "Conflict full vector (right)" :
                        x == "OP-FV_L" ?  "Conflict full vector (left)" :
                        x == "HV"      ?  "Half vector" :
                        x

speed_interval = 10
speed_breaks = 0:speed_interval:200
speed_mid = Int.(midpoints(speed_breaks))
#
__getspeed(a1::Point2f0, a2::Point2f0) = norm(a2 - a1)
__getspeed(a1, a2) = missing
__getdistance(::Missing, c) = missing
function __getdistance(a2, c)
  L = norm(a2 - c)
  i = Int(L ÷ speed_interval) + 1
end
function _getspeed(xy, c)
  y = Vector{Union{Missing, Float64}}(missing, length(speed_mid))
  length(xy) ≤ 1 && return y
  o = DataFrame(s = Base.splat(__getspeed).(partition(xy, 2, 1)), l = __getdistance.(xy[1:end-1], Ref(c)))
  dropmissing!(o)
  for (i, g) in  pairs(groupby(o, :l))
    y[i.l] = median(g.s)
  end
  return y
end

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
function get_speed(homing, turning_point, searching)
  y1 = reverse(_getspeed(reverse(homing), turning_point))
  y2 = _getspeed(searching, turning_point)
  return [y1; y2]
end
#
function rm2small!(df, cutoff = 5)
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

