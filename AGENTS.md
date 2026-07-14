# AGENTS.md

See `README.md` for the package overview (spike-driven relevance/region routing, `RegionRouter`).

## Cursor Cloud specific instructions

- Julia is provided via `juliaup` with default channel **1.12** (within this package's `1.9 - 1.12` compat). Standard setup: `julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'` (61 tests). Runnable examples: `julia --project=. examples/three_region.jl` (also `six_region.jl`, `reservoir_integration.jl`).
- Note: this directory's `Project.toml` declares `name = "TemporalFocus"` (a rename), which is distinct from the sibling `TemporalFocus.jl` repo (same name, different UUID and API). Always operate inside this repo's own `--project=.` environment so the two do not collide in a shared Julia environment.
