using Test
using TemporalFocus

@testset "TemporalFocus" begin

    # ── Generic API tests (preferred) ─────────────────────────────────────────

    @testset "ActivityRegion construction" begin
        r = ActivityRegion(8)
        @test r.last_spike_rate == 0.0f0
        @test length(r.output) == 8
        @test all(iszero, r.output)

        r2 = ActivityRegion(0.5f0, Float32[0.1, 0.2, 0.3])
        @test r2.last_spike_rate == 0.5f0
        @test length(r2.output) == 3
    end

    @testset "RegionRouter construction" begin
        router = RegionRouter()
        @test router.n_regions == 4
        @test router.n_out == 16
        @test length(router.routing_weights) == 4
        @test isapprox(sum(router.routing_weights), 1.0f0, atol = 1e-5)
        @test router.tick_count == 0
        @test router.region_names == ["Region1", "Region2", "Region3", "Region4"]
    end

    @testset "update_routing! sums to 1.0" begin
        router = RegionRouter()
        regions = [ActivityRegion(rand(Float32), rand(Float32, 16)) for _ = 1:4]
        update_routing!(router, regions)
        @test isapprox(sum(router.routing_weights), 1.0f0, atol = 1e-4)
        @test router.tick_count == 1
    end

    @testset "routing_diagnostics non-empty" begin
        router = RegionRouter()
        regions = [ActivityRegion(rand(Float32), rand(Float32, 16)) for _ = 1:4]
        update_routing!(router, regions)
        s = routing_diagnostics(router)
        @test length(s) > 0
        @test occursin("tick=", s)
        @test occursin("dominant", s)
    end

    @testset "active region gains relevance" begin
        router = RegionRouter()
        for _ = 1:30
            regions = [
                ActivityRegion(1.0f0, ones(Float32, 16)),
                ActivityRegion(0.0f0, zeros(Float32, 16)),
                ActivityRegion(0.0f0, zeros(Float32, 16)),
                ActivityRegion(0.0f0, zeros(Float32, 16)),
            ]
            update_routing!(router, regions)
        end
        @test router.routing_weights[1] > router.routing_weights[2]
        @test router.routing_weights[1] > router.routing_weights[3]
        @test router.routing_weights[1] > router.routing_weights[4]
    end

    @testset "custom region count" begin
        router = RegionRouter(n_regions = 3, n_out = 8, region_names = ["A", "B", "C"])
        regions = [ActivityRegion(rand(Float32), rand(Float32, 8)) for _ = 1:3]
        update_routing!(router, regions)
        @test length(router.routing_weights) == 3
        @test isapprox(sum(router.routing_weights), 1.0f0, atol = 1e-4)
    end

    # ── Backward compatibility tests ─────────────────────────────────────────

    @testset "backward-compatible aliases exist" begin
        @test LobeState === ActivityRegion
        @test NeroOrchestrator === RegionRouter
        @test update_relevance! === update_routing!
        @test nero_diagnostics === routing_diagnostics
    end

    @testset "LobeState construction (backward compat)" begin
        l = LobeState(8)
        @test l isa ActivityRegion
        @test l.last_spike_rate == 0.0f0
        @test length(l.output) == 8
    end

    @testset "NeroOrchestrator construction (backward compat)" begin
        n = NeroOrchestrator()
        @test n isa RegionRouter
        @test n.n_regions == 4
        @test n.n_out == 16
        @test isapprox(sum(n.routing_weights), 1.0f0, atol = 1e-5)
        @test n.tick_count == 0
    end

    @testset "update_relevance! works (backward compat)" begin
        n = NeroOrchestrator()
        lobes = [LobeState(rand(Float32), rand(Float32, 16)) for _ = 1:4]
        update_relevance!(n, lobes)
        @test isapprox(sum(n.routing_weights), 1.0f0, atol = 1e-4)
        @test n.tick_count == 1
    end

    @testset "all scores ≥ MIN_SCORE" begin
        router = RegionRouter()
        for _ = 1:20
            regions = [ActivityRegion(rand(Float32), rand(Float32, 16)) for _ = 1:4]
            update_routing!(router, regions)
        end
        for r in router.routing_weights
            @test r >= TemporalFocus.MIN_SCORE
        end
    end

    @testset "tick counter increments" begin
        router = RegionRouter()
        regions = [ActivityRegion(16) for _ = 1:4]
        for i = 1:5
            update_routing!(router, regions)
            @test router.tick_count == i
        end
    end

    @testset "diagnostics string contains expected content" begin
        router = RegionRouter()
        regions = [ActivityRegion(rand(Float32), rand(Float32, 16)) for _ = 1:4]
        update_routing!(router, regions)
        s = routing_diagnostics(router)
        @test length(s) > 0
        @test occursin("tick=", s)
        @test occursin("dominant", s)
    end

    @testset "prev_relevance field exists and is populated (regression LIM-5)" begin
        router = RegionRouter()
        @test hasproperty(router, :prev_relevance)
        @test length(router.prev_relevance) == 4
        @test all(iszero, router.prev_relevance)

        regions = [
            ActivityRegion(1.0f0, ones(Float32, 16)),
            ActivityRegion(0.0f0, zeros(Float32, 16)),
            ActivityRegion(0.0f0, zeros(Float32, 16)),
            ActivityRegion(0.0f0, zeros(Float32, 16)),
        ]
        update_routing!(router, regions)

        @test !all(iszero, router.prev_relevance)
        @test length(router.prev_relevance) == 4

        prev_first = copy(router.prev_relevance)
        update_routing!(router, regions)
        @test router.prev_relevance != prev_first
    end

    @testset "NERO_* constant aliases exist" begin
        @test TemporalFocus.NERO_ALPHA === TemporalFocus.ALPHA
        @test TemporalFocus.NERO_BETA === TemporalFocus.BETA
        @test TemporalFocus.NERO_GAMMA === TemporalFocus.GAMMA
        @test TemporalFocus.NERO_EMA_DECAY === TemporalFocus.EMA_DECAY
        @test TemporalFocus.NERO_MIN_SCORE === TemporalFocus.MIN_SCORE
        @test TemporalFocus.NERO_EPSILON === TemporalFocus.EPSILON
        @test TemporalFocus.NERO_DEFAULT_LOBE_NAMES === TemporalFocus.DEFAULT_REGION_NAMES
        @test TemporalFocus.NERO_INHIBIT === TemporalFocus.INHIBIT
    end

end
