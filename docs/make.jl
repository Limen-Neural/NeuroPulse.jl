# SPDX-License-Identifier: MIT OR Apache-2.0
using Documenter
using TemporalFocus

makedocs(;
    modules = [TemporalFocus],
    authors = "Limen Neural and contributors",
    sitename = "TemporalFocus.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://Limen-Neural.github.io/NeuroPulse.jl",
        edit_link = "main",
        assets = String[],
        repolink = "https://github.com/Limen-Neural/NeuroPulse.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Overview" => "overview.md",
        "API" => "api.md",
        "Interop" => "interop.md",
        "Roadmap" => "roadmap.md",
    ],
    # Early-stage package: allow missing docstrings without failing the build.
    warnonly = [:missing_docs],
)

deploydocs(;
    repo = "github.com/Limen-Neural/NeuroPulse.jl.git",
    devbranch = "main",
    push_preview = true,
)
