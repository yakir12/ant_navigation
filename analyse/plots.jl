styles = (
          homing        = (label = "homing", linewidth = 1,),
          searching     = (label = "searching", linewidth = 0.5,),
          turning_point = (label = "turning point", marker    = :dtriangle,),
          dropoff       = (label = "drop-off", marker    = '•', color = :white, strokewidth = 1, markersize = 25),
          nest          = (label = "nest", marker    = :star5, strokecolor = :white, strokewidth = 0.2),
          fictive_nest  = (label = "fictive nest", marker = :star5, color = :white, strokewidth = 1,),
         )

make_transparent(c) = RGBA(RGB(CairoMakie.to_color(c)), 0.5)

function plottrack(ax, dropoff, homing, turning_point, searching, fictive_nest, figure, color)
  lines!(ax, homing; color, styles.homing...)
  if figure ≠ :conflict
    lines!(ax, searching; color = make_transparent(color), styles.searching...)
  end
  if figure == :displacement
    scatter!(ax, dropoff; strokecolor = color, styles.dropoff...)
  end
  # scatter!(ax, turning_point; color, styles.turning_point...)
  # arrows!(ax, [turning_point], [1normalize(searching[1] - homing[end - 1])]; color, label = "turning point")
  x, y = length(homing) == 1 ? searching[2] - homing[1] : searching[1] - homing[end - 1]
  scatter!(ax, turning_point; color, styles.turning_point..., rotations = π/2 + atan(y, x))
  # text!(ax, "💧"; position = turning_point, rotation = π/2 + atan(reverse(searching[1] - homing[end - 1])...), align = (:center, :center))
end

function plottracks(ax, dropoff, homing, turning_point, searching, fictive_nest, nest, figure, color)
  plottrack.(ax, dropoff, homing, turning_point, searching, fictive_nest, figure, color)
  if figure[1] ≠ :displacement
    scatter!(ax, dropoff[1]; strokecolor = color, styles.dropoff...)
    scatter!(ax, fictive_nest[1]; strokecolor = color, styles.fictive_nest...)
  else
    scatter!(ax, nest[1]; color, styles.nest...)
  end
end

function plottracks(df; color = :black)
  fig = Figure()
  for (i, (k, gd)) in enumerate(pairs(groupby(df, :treatment, sort = true)))
    ax = Axis(fig[1,i], aspect = DataAspect(), title = string(k...), ylabel = "Y (cm)")
    plottracks(ax, gd.dropoff, gd.homing, gd.turning_point, gd.searching, gd.fictive_nest, gd.nest, gd.figure, color)
  end
  axs = contents(fig[1, :])
  linkaxes!(axs...)
  hideydecorations!.(axs[2:end], grid = false)
  Label(fig[2,:], "X (cm)", tellwidth = false, tellheight = true)
  Legend(fig[3, :], axs[1], orientation = :horizontal, tellwidth = false, tellheight = true, merge = true, unique = true)
  rowsize!(fig.layout, 1, Aspect(1,1))
  # resize!(fig.scene, gridlayoutsize(fig.layout) .+ (1, 1))
  fig
end

function plotspeeds(df, Mx, My; color = :black)
  fig = Figure()
  for (i, (k, gd)) in enumerate(pairs(groupby(df, :treatment, sort = true)))
    ax = Axis(fig[1,i], title = string(k...), ylabel = "Speed (cm/sec)")
    boxplot!(ax, gd.distance, color = color, gd.speed, width=speed_interval/2, show_median=true, show_outliers = false)
    vlines!(ax, 0, color = :gray)
  end
  axs = contents(fig[1, :])
  linkaxes!(axs...)
  xlims!(axs[1], -Mx, Mx)
  ylims!(axs[1], nothing, My)
  hideydecorations!.(axs[2:end], grid = false)
  Label(fig[2,:], "Radial distance from the turning point (cm)", tellwidth = false, tellheight = true)
  rowsize!(fig.layout, 1, Aspect(1,1))
  # resize!(fig.scene, gridlayoutsize(fig.layout) .+ (1, 1))
  fig
end

# function ploteach(df)
#   fig = Figure()
#   sl = Slider(fig[2, 1], range = 1:nrow(df))
#   homing = lift(sl.value) do i
#     Vector{Union{Missing, Point2f0}}(df.homing[i])
#   end
#   turning_point = lift(sl.value) do i
#     df.turning_point[i]
#   end
#   searching = lift(sl.value) do i
#     Vector{Union{Missing, Point2f0}}(df.searching[i])
#   end
#   ax = Axis(fig[1,1], aspect = DataAspect(), title = lift(string, sl.value))
#   lines!(ax, homing; styles.homing...)
#   scatter!(ax, turning_point; styles.turning_point...)
#   lines!(ax, searching; styles.searching...)
#   on(sl.value) do _
#     autolimits!(ax)
#   end
#   fig
# end
#
# using GLMakie
# GLMakie.activate!()
# fig = ploteach(df)
#
#

