# TemporalFocus documentation index

Documenter builds from `docs/src/` via `docs/make.jl` and deploys to GitHub Pages.

- Published: [stable](https://limen-neural.github.io/NeuroPulse.jl/stable) · [dev](https://limen-neural.github.io/NeuroPulse.jl/dev)
- `src/index.md` — Documenter home
- `overview.md` / `src/overview.md` — scope, architecture, and intended usage
- `api.md` / `src/api.md` — exported API notes and current limitations
- `interop.md` — frozen data-shape / interop contract (LIM-228 / GH#14)
- `roadmap.md` / `src/roadmap.md` — candid status and next cleanup targets

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
```
