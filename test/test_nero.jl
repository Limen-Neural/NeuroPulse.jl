using Test
using TemporalFocus

@testset "TemporalFocus" begin

    @testset "NeroOrchestrator construction" begin
        nero = NeroOrchestrator()
        @test nero.n_lobes == 4
        @test nero.n_out == 16
        @test length(nero.routing_weights) == 4
        @test isapprox(sum(nero.routing_weights), 1.0f0, atol=1e-5)
        @test nero.tick_count == 0
    end

    @testset "relevance sums to 1.0" begin
        nero = NeroOrchestrator()
        lobes = [LobeState(rand(Float32), rand(Float32, 16)) for _ in 1:4]
        update_relevance!(nero, lobes)
        @test isapprox(sum(nero.routing_weights), 1.0f0, atol=1e-4)
        @test nero.tick_count == 1
    end

    @testset "all scores ≥ NERO_MIN_SCORE" begin
        nero = NeroOrchestrator()
        for _ in 1:20
            lobes = [LobeState(rand(Float32), rand(Float32, 16)) for _ in 1:4]
            update_relevance!(nero, lobes)
        end
        for r in nero.routing_weights
            @test r >= TemporalFocus.NERO_MIN_SCORE
        end
    end

    @testset "active lobe gains relevance" begin
        nero = NeroOrchestrator()
        # Lobe 1 always fires, others silent
        for _ in 1:30
            lobes = [
                LobeState(1.0f0, ones(Float32, 16)),
                LobeState(0.0f0, zeros(Float32, 16)),
                LobeState(0.0f0, zeros(Float32, 16)),
                LobeState(0.0f0, zeros(Float32, 16)),
            ]
            update_relevance!(nero, lobes)
        end
        @test nero.routing_weights[1] > nero.routing_weights[2]
        @test nero.routing_weights[1] > nero.routing_weights[3]
        @test nero.routing_weights[1] > nero.routing_weights[4]
    end

    @testset "tick counter increments" begin
        nero = NeroOrchestrator()
        lobes = [LobeState(16) for _ in 1:4]
        for i in 1:5
            update_relevance!(nero, lobes)
            @test nero.tick_count == i
        end
    end

    @testset "diagnostics string non-empty" begin
        nero = NeroOrchestrator()
        lobes = [LobeState(rand(Float32), rand(Float32, 16)) for _ in 1:4]
        update_relevance!(nero, lobes)
        s = nero_diagnostics(nero)
        @test length(s) > 0
        @test occursin("NERO", s)
        @test occursin("dominant", s)
    end

    @testset "custom lobe count" begin
        nero = NeroOrchestrator(n_lobes=3, n_out=8, lobe_names=["A","B","C"])
        lobes = [LobeState(rand(Float32), rand(Float32, 8)) for _ in 1:3]
        update_relevance!(nero, lobes)
        @test length(nero.routing_weights) == 3
        @test isapprox(sum(nero.routing_weights), 1.0f0, atol=1e-4)
    end

    @testset "prev_relevance field exists and is populated (regression LIM-5)" begin
        nero = NeroOrchestrator()
        # Field must exist and start zeroed
        @test hasproperty(nero, :prev_relevance)
        @test length(nero.prev_relevance) == 4
        @test all(iszero, nero.prev_relevance)

        lobes = [LobeState(1.0f0, ones(Float32, 16)),
                 LobeState(0.0f0, zeros(Float32, 16)),
                 LobeState(0.0f0, zeros(Float32, 16)),
                 LobeState(0.0f0, zeros(Float32, 16))]
        update_relevance!(nero, lobes)

        # After first tick prev_relevance should hold the raw scores, not zeros
        @test !all(iszero, nero.prev_relevance)
        @test length(nero.prev_relevance) == 4

        # Second tick: prev_relevance is updated in-place as a scratch buffer,
        # so its contents will differ from the previous tick's raw values
        prev_first = copy(nero.prev_relevance)
        update_relevance!(nero, lobes)
        @test nero.prev_relevance != prev_first
    end

end
