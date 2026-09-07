# SPDX-License-Identifier: MIT OR Apache-2.0

using Test
using TemporalFocus
using Pkg

const SURVIVOR_UUID = Base.UUID("b7e4c3f2-1d2e-4a5b-8c9d-0e1f2a3b4c5e")
const RETIRED_TF_UUID = Base.UUID("7f3c9f2a-6b2e-4d91-9c4f-1a2b3c4d5e6f")

@testset "Package identity (ADR 0002)" begin
    id = Base.PkgId(TemporalFocus)
    @test id.name == "TemporalFocus"
    @test id.uuid == SURVIVOR_UUID
    @test id.uuid != RETIRED_TF_UUID

    # A single environment must not resolve two packages named TemporalFocus.
    named = Dict{String,Vector{Base.UUID}}()
    for (uuid, spec) in Pkg.dependencies()
        push!(get!(Vector{Base.UUID}, named, spec.name), uuid)
    end
    @test haskey(named, "TemporalFocus")
    @test length(named["TemporalFocus"]) == 1
    @test only(named["TemporalFocus"]) == SURVIVOR_UUID
    @test RETIRED_TF_UUID ∉ named["TemporalFocus"]
end
