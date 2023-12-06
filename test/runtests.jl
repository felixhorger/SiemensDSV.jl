
import Pkg
Pkg.activate(".")

using SiemensDSV
using MAT

# Sorry local path...
dsv = dsvread(expanduser("~/data/20231124_GIRF/caspr/caspr_GRX.dsv"))

dsv_target = matread(expanduser("~/data/20231124_GIRF/caspr/gx.mat"))

@assert all(v -> v[1] == v[2], zip(dsv_target["values"], dsv.values))

# TODO check other properties




