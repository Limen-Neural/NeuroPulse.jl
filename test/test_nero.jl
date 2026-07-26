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

    # ── Configurable inhibition matrix (LIM-229 / GH#23) ─────────────────────

    @testset "inhibition_matrix: NERO_INHIBIT === INHIBIT" begin
        @test TemporalFocus.NERO_INHIBIT === TemporalFocus.INHIBIT
    end

    @testset "inhibition_matrix: n=4 default equals historical INHIBIT" begin
        router = RegionRouter()
        @test hasproperty(router, :inhibition_matrix)
        @test size(router.inhibition_matrix) == (4, 4)
        @test router.inhibition_matrix == TemporalFocus.INHIBIT
        @test eltype(router.inhibition_matrix) == Float32
    end

    @testset "inhibition_matrix: n=3 default equals INHIBIT[1:3,1:3]" begin
        router = RegionRouter(n_regions = 3, n_out = 8)
        expected = TemporalFocus.INHIBIT[1:3, 1:3]
        @test size(router.inhibition_matrix) == (3, 3)
        @test router.inhibition_matrix == expected
        @test eltype(router.inhibition_matrix) == Float32
        # Historical asymmetry preserved (2→1 is 0.04, not geometric 0.08)
        @test router.inhibition_matrix[2, 1] == 0.04f0
        @test router.inhibition_matrix[1, 2] == 0.08f0
    end

    @testset "inhibition_matrix: n=6 default has zero diagonal and positive off-diag" begin
        router = RegionRouter(n_regions = 6, n_out = 8)
        M = router.inhibition_matrix
        @test size(M) == (6, 6)
        @test eltype(M) == Float32
        for i = 1:6
            @test M[i, i] == 0.0f0
        end
        @test any(M[i, j] > 0 for i = 1:6, j = 1:6 if i != j)
    end

    @testset "inhibition_matrix: n=6 update_routing! runs without error" begin
        router = RegionRouter(n_regions = 6, n_out = 8)
        regions = [ActivityRegion(rand(Float32), rand(Float32, 8)) for _ = 1:6]
        update_routing!(router, regions)
        @test length(router.routing_weights) == 6
        @test isapprox(sum(router.routing_weights), 1.0f0, atol = 1e-4)
        @test router.tick_count == 1
    end

    @testset "inhibition_matrix: non-zero inhibition differs from zero matrix" begin
        n = 4
        n_out = 8
        names = ["A", "B", "C", "D"]
        regions = [
            ActivityRegion(1.0f0, ones(Float32, n_out)),
            ActivityRegion(0.8f0, 0.8f0 .* ones(Float32, n_out)),
            ActivityRegion(0.2f0, 0.2f0 .* ones(Float32, n_out)),
            ActivityRegion(0.1f0, 0.1f0 .* ones(Float32, n_out)),
        ]

        r_zero = RegionRouter(
            n_regions = n,
            n_out = n_out,
            region_names = names,
            inhibition_matrix = zeros(Float32, n, n),
        )
        r_inh = RegionRouter(
            n_regions = n,
            n_out = n_out,
            region_names = names,
            inhibition_matrix = TemporalFocus.INHIBIT,
        )
        for _ = 1:10
            update_routing!(r_zero, regions)
            update_routing!(r_inh, regions)
        end
        @test r_zero.routing_weights != r_inh.routing_weights
    end

    @testset "inhibition_matrix: custom matrix accepted" begin
        custom = Float32[
            0.0 0.1 0.0
            0.05 0.0 0.1
            0.0 0.05 0.0
        ]
        router = RegionRouter(
            n_regions = 3,
            n_out = 4,
            region_names = ["A", "B", "C"],
            inhibition_matrix = custom,
        )
        @test router.inhibition_matrix == custom
        @test eltype(router.inhibition_matrix) == Float32
        regions = [ActivityRegion(rand(Float32), rand(Float32, 4)) for _ = 1:3]
        update_routing!(router, regions)
        @test isapprox(sum(router.routing_weights), 1.0f0, atol = 1e-4)
    end

    @testset "inhibition_matrix: wrong size throws ArgumentError" begin
        @test_throws ArgumentError RegionRouter(
            n_regions = 3,
            inhibition_matrix = zeros(Float32, 2, 2),
        )
    end


    # ── Checkpointing (LIM-234 / GH#28) ───────────────────────────────────────

    @testset "save_state / load_state! round-trip" begin
        router = RegionRouter(n_regions = 3, n_out = 8, region_names = ["A", "B", "C"])
        for _ = 1:5
            regions = [
                ActivityRegion(0.9f0, ones(Float32, 8)),
                ActivityRegion(0.1f0, 0.2f0 .* ones(Float32, 8)),
                ActivityRegion(0.0f0, zeros(Float32, 8)),
            ]
            update_routing!(router, regions)
        end

        snap = save_state(router)
        @test snap isa NamedTuple
        @test snap.n_regions == 3
        @test snap.n_out == 8
        @test snap.tick_count == 5
        @test snap.region_names == ["A", "B", "C"]
        @test snap.region_names !== router.region_names
        @test snap.routing_weights == router.routing_weights
        @test snap.readout_ema == router.readout_ema
        # Snapshot must own independent buffers (not views into the router)
        @test snap.routing_weights !== router.routing_weights
        @test snap.readout_ema !== router.readout_ema
        @test snap.spike_density !== router.spike_density
        @test snap.prev_routing_weights !== router.prev_routing_weights
        @test snap.prev_relevance !== router.prev_relevance
        @test snap.surprise !== router.surprise
        @test snap.scratch !== router.scratch

        # Capture expected state at the snapshot point
        expected_weights = copy(router.routing_weights)
        expected_ema = copy(router.readout_ema)
        expected_density = copy(router.spike_density)
        expected_prev_w = copy(router.prev_routing_weights)
        expected_prev_rel = copy(router.prev_relevance)
        expected_surprise = copy(router.surprise)
        expected_scratch = copy(router.scratch)
        expected_tick = router.tick_count

        # Mutate router away from snapshot
        for _ = 1:3
            regions = [ActivityRegion(rand(Float32), rand(Float32, 8)) for _ = 1:3]
            update_routing!(router, regions)
        end
        @test router.tick_count == 8
        @test router.routing_weights != expected_weights

        # Restore
        load_state!(router, snap)
        @test router.tick_count == expected_tick
        @test router.routing_weights == expected_weights
        @test router.readout_ema == expected_ema
        @test router.spike_density == expected_density
        @test router.prev_routing_weights == expected_prev_w
        @test router.prev_relevance == expected_prev_rel
        @test router.surprise == expected_surprise
        @test router.scratch == expected_scratch

        # load_state alias works
        mutate_snap = save_state(router)
        router.tick_count = 0
        fill!(router.routing_weights, 0.0f0)
        load_state(router, mutate_snap)
        @test router.tick_count == expected_tick
        @test router.routing_weights == expected_weights

        # Further ticks after restore remain consistent with a fresh twin
        twin = RegionRouter(n_regions = 3, n_out = 8, region_names = ["A", "B", "C"])
        load_state!(twin, snap)
        regions = [
            ActivityRegion(0.5f0, 0.5f0 .* ones(Float32, 8)),
            ActivityRegion(0.4f0, 0.3f0 .* ones(Float32, 8)),
            ActivityRegion(0.2f0, 0.1f0 .* ones(Float32, 8)),
        ]
        update_routing!(router, regions)
        update_routing!(twin, regions)
        @test router.tick_count == twin.tick_count == expected_tick + 1
        @test router.routing_weights == twin.routing_weights
        @test router.readout_ema == twin.readout_ema
        @test router.surprise == twin.surprise
    end

    @testset "load_state! rejects dimension mismatch" begin
        router = RegionRouter(n_regions = 4, n_out = 16)
        other = RegionRouter(n_regions = 3, n_out = 8, region_names = ["A", "B", "C"])
        update_routing!(
            other,
            [ActivityRegion(rand(Float32), rand(Float32, 8)) for _ = 1:3],
        )
        snap = save_state(other)
        @test_throws ArgumentError load_state!(router, snap)

        # Same n_regions/n_out labels but wrong vector length
        bad = (
            n_regions = 4,
            n_out = 16,
            region_names = copy(router.region_names),
            adjacency_matrix = copy(router.adjacency_matrix),
            inhibition_matrix = copy(router.inhibition_matrix),
            routing_weights = zeros(Float32, 2),
            readout_ema = zeros(Float32, 4, 16),
            spike_density = zeros(Float32, 4),
            prev_routing_weights = zeros(Float32, 4),
            prev_relevance = zeros(Float32, 4),
            surprise = zeros(Float32, 4),
            scratch = zeros(Float32, 16),
            tick_count = Int64(0),
        )
        @test_throws ArgumentError load_state!(router, bad)
    end

    @testset "load_state! rejects region_names mismatch" begin
        source = RegionRouter(n_regions = 3, n_out = 4, region_names = ["A", "B", "C"])
        update_routing!(
            source,
            [ActivityRegion(rand(Float32), rand(Float32, 4)) for _ = 1:3],
        )
        snap = save_state(source)
        target = RegionRouter(n_regions = 3, n_out = 4, region_names = ["X", "Y", "Z"])
        @test_throws ArgumentError load_state!(target, snap)
        err = try
            load_state!(target, snap)
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin("region_names", sprint(showerror, err))
    end

    @testset "load_state! rejects inhibition_matrix mismatch" begin
        n = 3
        n_out = 4
        names = ["A", "B", "C"]
        custom = Float32[
            0.0 0.1 0.0
            0.05 0.0 0.1
            0.0 0.05 0.0
        ]
        source = RegionRouter(
            n_regions = n,
            n_out = n_out,
            region_names = names,
            inhibition_matrix = custom,
        )
        update_routing!(
            source,
            [ActivityRegion(rand(Float32), rand(Float32, n_out)) for _ = 1:n],
        )
        snap = save_state(source)
        @test snap.inhibition_matrix == custom
        @test snap.inhibition_matrix !== source.inhibition_matrix

        # Same size, default inhibition — must not silently load
        target = RegionRouter(n_regions = n, n_out = n_out, region_names = names)
        @test target.inhibition_matrix != custom
        @test_throws ArgumentError load_state!(target, snap)

        # Matching custom matrix still loads
        twin = RegionRouter(
            n_regions = n,
            n_out = n_out,
            region_names = names,
            inhibition_matrix = custom,
        )
        load_state!(twin, snap)
        @test twin.routing_weights == source.routing_weights
        @test twin.tick_count == source.tick_count
    end

    @testset "load_state! rejects snapshot missing structural fields" begin
        router = RegionRouter(n_regions = 3, n_out = 4, region_names = ["A", "B", "C"])
        update_routing!(
            router,
            [ActivityRegion(rand(Float32), rand(Float32, 4)) for _ = 1:3],
        )
        snap = save_state(router)
        # Older/hand-built snapshot without structural fields
        incomplete = (
            n_regions = snap.n_regions,
            n_out = snap.n_out,
            routing_weights = snap.routing_weights,
            readout_ema = snap.readout_ema,
            spike_density = snap.spike_density,
            prev_routing_weights = snap.prev_routing_weights,
            prev_relevance = snap.prev_relevance,
            surprise = snap.surprise,
            scratch = snap.scratch,
            tick_count = snap.tick_count,
        )
        @test_throws ArgumentError load_state!(router, incomplete)

        # Missing only adjacency_matrix
        no_adj = (
            n_regions = snap.n_regions,
            n_out = snap.n_out,
            region_names = snap.region_names,
            inhibition_matrix = snap.inhibition_matrix,
            routing_weights = snap.routing_weights,
            readout_ema = snap.readout_ema,
            spike_density = snap.spike_density,
            prev_routing_weights = snap.prev_routing_weights,
            prev_relevance = snap.prev_relevance,
            surprise = snap.surprise,
            scratch = snap.scratch,
            tick_count = snap.tick_count,
        )
        err_adj = try
            load_state!(router, no_adj)
            nothing
        catch e
            e
        end
        @test err_adj isa ArgumentError
        @test occursin("adjacency_matrix", sprint(showerror, err_adj))

        # Missing only inhibition_matrix
        no_inh = (
            n_regions = snap.n_regions,
            n_out = snap.n_out,
            region_names = snap.region_names,
            adjacency_matrix = snap.adjacency_matrix,
            routing_weights = snap.routing_weights,
            readout_ema = snap.readout_ema,
            spike_density = snap.spike_density,
            prev_routing_weights = snap.prev_routing_weights,
            prev_relevance = snap.prev_relevance,
            surprise = snap.surprise,
            scratch = snap.scratch,
            tick_count = snap.tick_count,
        )
        err_inh = try
            load_state!(router, no_inh)
            nothing
        catch e
            e
        end
        @test err_inh isa ArgumentError
        @test occursin("inhibition_matrix", sprint(showerror, err_inh))

        # Missing only region_names
        no_names = (
            n_regions = snap.n_regions,
            n_out = snap.n_out,
            adjacency_matrix = snap.adjacency_matrix,
            inhibition_matrix = snap.inhibition_matrix,
            routing_weights = snap.routing_weights,
            readout_ema = snap.readout_ema,
            spike_density = snap.spike_density,
            prev_routing_weights = snap.prev_routing_weights,
            prev_relevance = snap.prev_relevance,
            surprise = snap.surprise,
            scratch = snap.scratch,
            tick_count = snap.tick_count,
        )
        err_names = try
            load_state!(router, no_names)
            nothing
        catch e
            e
        end
        @test err_names isa ArgumentError
        @test occursin("region_names", sprint(showerror, err_names))
    end

    # ── adapt_leak! (LIM-233 / GH#27) ──────────────────────────────────────────

    @testset "adapt_leak! default stress percent scale [0, 100]" begin
        # Default adapter: stress is a percent-like signal in [0, 100] → unit interval,
        # then lerped to leak bounds. (Back-compat with old fan-speed call sites.)
        leak = Ref(0.0f0)
        adapt_leak!(leak, 0)   # zero stress → min_leak
        @test leak[] == 0.01f0

        adapt_leak!(leak, 100) # full stress → max_leak
        @test leak[] == 0.25f0

        adapt_leak!(leak, 50)  # mid stress
        @test isapprox(leak[], 0.13f0, atol = 1e-5)

        # stress outside [0, 100] clamps to endpoints
        adapt_leak!(leak, -10)
        @test leak[] == 0.01f0
        adapt_leak!(leak, 200)
        @test leak[] == 0.25f0
    end

    @testset "adapt_leak! custom min/max with stress" begin
        leak = Ref(0.0f0)
        adapt_leak!(leak, 0; min_leak = 0.05f0, max_leak = 0.50f0)
        @test leak[] == 0.05f0

        adapt_leak!(leak, 100; min_leak = 0.05f0, max_leak = 0.50f0)
        @test leak[] == 0.50f0

        adapt_leak!(leak, 50; min_leak = 0.05f0, max_leak = 0.50f0)
        @test isapprox(leak[], 0.275f0, atol = 1e-5)
    end

    @testset "adapt_leak! Real stress bounds kwargs" begin
        leak = Ref(0.0f0)
        # Float64 kwargs accepted and converted to Float32 internally
        adapt_leak!(leak, 0; min_leak = 0.05, max_leak = 0.50)
        @test leak[] == 0.05f0

        adapt_leak!(leak, 100; min_leak = 0.05, max_leak = 0.50)
        @test leak[] == 0.50f0

        adapt_leak!(leak, 50; min_leak = 0.05, max_leak = 0.50)
        @test isapprox(leak[], 0.275f0, atol = 1e-5)
    end

    @testset "adapt_leak! inverted stress bounds" begin
        leak = Ref(0.0f0)
        @test_throws ArgumentError adapt_leak!(leak, 50; min_leak = 0.5f0, max_leak = 0.1f0)
        @test_throws ArgumentError adapt_leak!(leak, 50; min_leak = 0.5, max_leak = 0.1)
    end

    @testset "adapt_leak! custom stress_adapter" begin
        leak = Ref(0.0f0)
        # identity adapter: stress already in unit interval [0, 1]
        unit_adapter = s -> Float32(s)
        adapt_leak!(leak, 0.0; stress_adapter = unit_adapter)
        @test leak[] == 0.01f0

        adapt_leak!(leak, 1.0; stress_adapter = unit_adapter)
        @test leak[] == 0.25f0

        adapt_leak!(leak, 0.5; stress_adapter = unit_adapter)
        @test isapprox(leak[], 0.13f0, atol = 1e-5)

        # custom stress adapter + custom min/max
        adapt_leak!(
            leak,
            0.25;
            min_leak = 0.1f0,
            max_leak = 0.9f0,
            stress_adapter = unit_adapter,
        )
        @test isapprox(leak[], 0.1f0 + 0.25f0 * (0.9f0 - 0.1f0), atol = 1e-5)
    end

    @testset "adapt_leak! rejects non-finite bounds" begin
        leak = Ref(0.0f0)
        @test_throws ArgumentError adapt_leak!(leak, 50; min_leak = NaN)
        @test_throws ArgumentError adapt_leak!(leak, 50; max_leak = Inf)
        @test_throws ArgumentError adapt_leak!(leak, 50; min_leak = -Inf, max_leak = Inf)
        @test_throws ArgumentError adapt_leak!(leak, 50; min_leak = NaN, max_leak = 0.2f0)
    end

    @testset "adapt_leak! clamps custom adapter output" begin
        leak = Ref(0.0f0)
        over_adapter = s -> Float32(s) + 10.0f0
        adapt_leak!(leak, 50.0; stress_adapter = over_adapter)
        @test leak[] == 0.25f0

        under_adapter = s -> Float32(s) - 100.0f0
        adapt_leak!(leak, 50.0; stress_adapter = under_adapter)
        @test leak[] == 0.01f0

        # clamping respects custom bounds
        adapt_leak!(
            leak,
            50.0;
            min_leak = 0.1f0,
            max_leak = 0.5f0,
            stress_adapter = over_adapter,
        )
        @test leak[] == 0.5f0
    end

end
