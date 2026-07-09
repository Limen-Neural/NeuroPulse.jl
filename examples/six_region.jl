# SPDX-License-Identifier: MIT OR Apache-2.0

using TemporalFocus

# Custom layouts may exceed the fixed 4×4 lateral-inhibition table
# (`TemporalFocus.INHIBIT`). That is intentional here: `update_routing!`
# bounds-checks every INHIBIT access (`src/dst <= size(INHIBIT, …)`), so
# region indices beyond the table simply contribute 0 lateral inhibition
# rather than throwing BoundsError. Prefer documenting the limit over
# hard-erroring — a hard error would prevent this worked 6-region demo.
const N_REGIONS = 6
const INHIBIT_DIM = size(TemporalFocus.INHIBIT, 1)
if N_REGIONS > INHIBIT_DIM
    @info "n_regions=$N_REGIONS exceeds INHIBIT size $(INHIBIT_DIM)×$(INHIBIT_DIM); " *
          "pairs involving region index > $INHIBIT_DIM skip lateral inhibition (safe)"
end

router = RegionRouter(
    n_regions = N_REGIONS,
    n_out = 3,
    region_names = ["vision", "audio", "touch", "context", "planner", "action"],
)

# Keep this example focused on custom region sizing / naming. Zeroing the
# adjacency matrix fully disables graph inhibition for this demo (INHIBIT
# is only consulted when adjacency_matrix[src, dst] > 0).
router.adjacency_matrix .= 0.0f0

regions = [
    ActivityRegion(0.92f0, Float32[0.9, 0.6, 0.2]),
    ActivityRegion(0.44f0, Float32[0.3, 0.8, 0.4]),
    ActivityRegion(0.31f0, Float32[0.2, 0.5, 0.7]),
    ActivityRegion(0.58f0, Float32[0.6, 0.6, 0.5]),
    ActivityRegion(0.27f0, Float32[0.4, 0.3, 0.9]),
    ActivityRegion(0.12f0, Float32[0.1, 0.2, 0.8]),
]

update_routing!(router, regions)

println("Six-region custom layout:")
for (name, weight) in zip(router.region_names, router.routing_weights)
    println(rpad(name, 10), " => ", round(weight; digits = 3))
end
println(routing_diagnostics(router))
