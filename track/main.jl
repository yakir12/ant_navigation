import Pkg
Pkg.activate(".")
Pkg.instantiate()

using LazyArtifacts
using MAT2db

xs = process_csv(artifact"csvfile.csv/csvfile.csv", data_folder = x -> joinpath(@artifact_str(string(x)), string(x)))
save2db(xs, artifact"factors_file.csv/factors_file.csv", filename = joinpath("..", "results", "db.arrow"))

