using IntervalSets
using Test
using Dates
using Statistics
import Statistics: mean
using Random
using Unitful

import IntervalSets: Domain, endpoints, closedendpoints, TypedEndpointsInterval

struct MyClosedUnitInterval <: TypedEndpointsInterval{:closed,:closed,Int} end
endpoints(::MyClosedUnitInterval) = (0,1)
Base.promote_rule(::Type{MyClosedUnitInterval}, ::Type{ClosedInterval{T}}) where T =
        ClosedInterval{T}

struct MyUnitInterval <: AbstractInterval{Int}
    isleftclosed::Bool
    isrightclosed::Bool
end
endpoints(::MyUnitInterval) = (0,1)
closedendpoints(I::MyUnitInterval) = (I.isleftclosed,I.isrightclosed)

struct IncompleteInterval <: AbstractInterval{Int} end

@testset "IntervalSets" begin
    @test isempty(detect_ambiguities(IntervalSets))

    @test ordered(2, 1) == (1, 2)
    @test ordered(1, 2) == (1, 2)
    @test ordered(Float16(1), 2) == (1, 2)

    @testset "Basic Closed Sets" begin
        @test_throws ErrorException :a .. "b"
        @test_throws ErrorException 1 .. missing
        @test_throws ErrorException 1u"m" .. 2u"s"
        I = 0..3
        @test I === ClosedInterval(0,3) === ClosedInterval{Int}(0,3) ===
                 Interval(0,3)
        @test string(I) == "0 .. 3"
        @test @inferred(UnitRange(I)) === 0:3
        @test @inferred(range(I)) === 0:3
        @test @inferred(UnitRange{Int16}(I)) === Int16(0):Int16(3)
        @test @inferred(ClosedInterval(0:3)) === I
        @test @inferred(ClosedInterval{Float64}(0:3)) === 0.0..3.0
        @test @inferred(ClosedInterval(Base.OneTo(3))) === 1..3
        J = 3..2
        K = 5..4
        L = 3 ± 2
        M = @inferred(ClosedInterval(2, 5.0))
        @test string(M) == "2.0 .. 5.0"
        N = @inferred(ClosedInterval(UInt8(255), 300))

        x, y = CartesianIndex(1, 2, 3, 4), CartesianIndex(1, 2, 3, 4)
        O = @inferred x±y
        @test O == ClosedInterval(x-y, x+y)

        @test eltype(I) == Int
        @test eltype(M) == Float64

        @test !isempty(I)
        @test isempty(J)
        @test J == K
        @test I != K
        @test I == I
        @test J == J
        @test L == L
        @test isequal(I, I)
        @test isequal(J, K)

        @test typeof(leftendpoint(M)) == typeof(rightendpoint(M)) && typeof(leftendpoint(M)) == Float64
        @test typeof(leftendpoint(N)) == typeof(rightendpoint(N)) && typeof(leftendpoint(N)) == Int
        @test @inferred(endpoints(M)) === (2.0,5.0)
        @test @inferred(endpoints(N)) === (255,300)

        @test maximum(I) === 3
        @test minimum(I) === 0
        @test extrema(I) === (0, 3)

        @test 2 in I
        @test issubset(1..2, 0.5..2.5)

        @test @inferred(I ∪ L) == ClosedInterval(0, 5)
        @test @inferred(I ∩ L) == ClosedInterval(1, 3)
        @test isempty(J ∩ K)
        @test isempty((2..5) ∩ (7..10))
        @test isempty((1..10) ∩ (7..2))
        A = Float16(1.1)..Float16(1.234)
        B = Float16(1.235)..Float16(1.3)
        C = Float16(1.236)..Float16(1.3)
        D = Float16(1.1)..Float16(1.236)
        @test D ∪ B == Float16(1.1)..Float16(1.3)
        @test D ∪ C == Float16(1.1)..Float16(1.3)
        @test_throws(ArgumentError, A ∪ C)

        @test 1.5 ∉ 0..1
        @test 1.5 ∉ 2..3
        # Throw error if the union is not an interval.
        @test_throws ArgumentError (0..1) ∪ (2..3)
        # Even though A and B contain all Float16s between their extrema,
        # union should not defined because there exists a Float64 inbetween.
        @test_throws ArgumentError A ∪ B
        x32 = nextfloat(rightendpoint(A))
        x64 = nextfloat(Float64(rightendpoint(A)))
        @test x32 ∉ A
        @test x32 ∈ B
        @test x64 ∉ A
        @test x64 ∉ B

        @test J ⊆ L
        @test (L ⊆ J) == false
        @test K ⊆ I
        @test ClosedInterval(1, 2) ⊆ I
        @test I ⊆ I
        @test (ClosedInterval(7, 9) ⊆ I) == false
        @test I ⊇ I
        @test I ⊇ ClosedInterval(1, 2)
        @test !(I ⊊ I)
        @test !(I ⊋ I)
        @test !(I ⊊ J)
        @test !(J ⊋ I)
        @test J ⊊ I
        @test I ⊋ J

        @test hash(1..3) == hash(1.0..3.0)

        @test width(I) == 3
        @test width(J) == 0

        @test width(ClosedInterval(3,7)) ≡ 4
        @test width(ClosedInterval(4.0,8.0)) ≡ 4.0

        @test mean(0..1) == 0.5

        @test promote(1..2, 1.0..2.0) === (1.0..2.0, 1.0..2.0)
    end

    @testset "Unitful interval" begin
        @test 1.5u"m" in 1u"m" .. 2u"m"
        @test 1500u"μm" in 1u"mm" .. 1u"m"
        @test !(500u"μm" in 1u"mm" .. 1u"m")
        @test 1u"m" .. 2u"m" == 1000u"mm" .. 2000u"mm"
    end

    @testset "Day interval" begin
        A = Date(1990, 1, 1); B = Date(1990, 3, 1)
        @test width(ClosedInterval(A, B)) == Dates.Day(59)
        @test width(ClosedInterval(B, A)) == Dates.Day(0)
        @test isempty(ClosedInterval(B, A))
    end

    @testset "isapprox" begin
        @test 1..2 ≈ 1..2
        @test 1..2 ≈ (1+1e-10)..2
        @test 1..2 ≉ 1..2.01
        @test 10..11 ≈ 10.1..10.9  rtol=0.01
        @test 10..11 ≈ 10.1..10.9  atol=0.1
        @test 10..11 ≉ 10.1..10.9  rtol=0.005
        @test 10..11 ≉ 10.1..10.9  atol=0.05
        @test 0..1 ≈ eps()..1
        @test 100.0..100.0 ≉ nextfloat(100.0)..100.0
        @test 3..1 ≈ 5..1
        @test_throws Exception OpenInterval(0, 1) ≈ ClosedInterval(0, 1)
    end

    @testset "Convert" begin
        I = 0..3
        @test @inferred(convert(ClosedInterval{Float64}, I))         ===
                @inferred(convert(AbstractInterval{Float64}, I))     ===
                @inferred(convert(Domain{Float64}, I))  ===
                @inferred(ClosedInterval{Float64}(I))                ===
                @inferred(convert(TypedEndpointsInterval{:closed,:closed,Float64},I)) ===
                0.0..3.0
        @test @inferred(convert(ClosedInterval, I))                  ===
                @inferred(convert(Interval, I))                      ===
                @inferred(ClosedInterval(I))                         ===
                @inferred(Interval(I))                               ===
                @inferred(convert(AbstractInterval, I))              ===
                @inferred(convert(Domain, I))           ===
                @inferred(convert(TypedEndpointsInterval{:closed,:closed}, I)) ===
                @inferred(convert(TypedEndpointsInterval{:closed,:closed,Int}, I)) ===
                @inferred(convert(ClosedInterval{Int}, I)) === I
        @test_throws InexactError convert(OpenInterval, I)
        @test_throws InexactError convert(Interval{:open,:closed}, I)
        @test_throws InexactError convert(Interval{:closed,:open}, I)
        @test !(convert(ClosedInterval{Float64}, I) === 0..3)
        @test ClosedInterval{Float64}(1,3) === 1.0..3.0
        @test ClosedInterval(0.5..2.5) === 0.5..2.5
        @test ClosedInterval{Int}(1.0..3.0) === 1..3
        J = OpenInterval(I)
        @test_throws InexactError convert(ClosedInterval, J)
        @test @inferred(convert(OpenInterval{Float64}, J))         ===
                @inferred(convert(AbstractInterval{Float64}, J))     ===
                @inferred(convert(Domain{Float64}, J)) ===
                @inferred(OpenInterval{Float64}(J))                === OpenInterval(0.0..3.0)
        @test @inferred(convert(OpenInterval, J))                ===
                @inferred(convert(Interval, J))                      ===
                @inferred(convert(AbstractInterval, J))              ===
                @inferred(convert(Domain, J))           ===
                @inferred(OpenInterval(J))                          ===
                @inferred(OpenInterval{Int}(J)) ===
                @inferred(convert(OpenInterval{Int},J)) === OpenInterval(J)
        J = Interval{:open,:closed}(I)
        @test_throws InexactError convert(Interval{:closed,:open}, J)
        @test @inferred(convert(Interval{:open,:closed,Float64}, J))         ===
                @inferred(convert(AbstractInterval{Float64}, J))     ===
                @inferred(convert(Domain{Float64}, J)) ===
                @inferred(Interval{:open,:closed,Float64}(J))                === Interval{:open,:closed}(0.0..3.0)
        @test @inferred(convert(Interval{:open,:closed}, J))                ===
                @inferred(convert(Interval, J))                      ===
                @inferred(convert(AbstractInterval, J))              ===
                @inferred(convert(Domain, J))           ===
                @inferred(Interval{:open,:closed}(J))                          === Interval{:open,:closed}(J)
        J = Interval{:closed,:open}(I)
        @test_throws InexactError convert(Interval{:open,:closed}, J)
        @test @inferred(convert(Interval{:closed,:open,Float64}, J))         ===
                @inferred(convert(AbstractInterval{Float64}, J))     ===
                @inferred(convert(Domain{Float64}, J)) ===
                @inferred(Interval{:closed,:open,Float64}(J))                === Interval{:closed,:open}(0.0..3.0)
        @test @inferred(convert(Interval{:closed,:open}, J))                ===
                @inferred(convert(Interval, J))                      ===
                @inferred(convert(AbstractInterval, J))              ===
                @inferred(convert(Domain, J))           ===
                @inferred(Interval{:closed,:open}(J))                          === Interval{:closed,:open}(J)

        @test 1.0..2.0 === 1.0..2 === 1..2.0 === ClosedInterval{Float64}(1..2) ===
                Interval(1.0,2.0)

        @test promote_type(Interval{:closed,:open,Float64}, Interval{:closed,:open,Int}) ===
                        Interval{:closed,:open,Float64}
    end


    @testset "Interval tests" begin
        for T in (Float32,Float64,BigFloat)
            d = zero(T) .. one(T)
            @test T(0.5) ∈ d
            @test T(1.1) ∉ d
            @test 0.5f0 ∈ d
            @test 1.1f0 ∉ d
            @test BigFloat(0.5) ∈ d
            @test BigFloat(1.1) ∉ d
            @test leftendpoint(d) ∈ d
            @test BigFloat(leftendpoint(d)) ∈ d
            @test nextfloat(leftendpoint(d)) ∈ d
            @test nextfloat(BigFloat(leftendpoint(d))) ∈ d
            @test prevfloat(leftendpoint(d)) ∉ d
            @test prevfloat(leftendpoint(d)) ∉ d
            @test rightendpoint(d) ∈ d
            @test BigFloat(rightendpoint(d)) ∈ d
            @test nextfloat(rightendpoint(d)) ∉ d
            @test nextfloat(BigFloat(rightendpoint(d))) ∉ d
            @test prevfloat(rightendpoint(d)) ∈ d
            @test prevfloat(rightendpoint(d)) ∈ d

            @test leftendpoint(d) == zero(T)
            @test rightendpoint(d) == one(T)
            @test minimum(d) == infimum(d) == leftendpoint(d)
            @test maximum(d) == supremum(d) == rightendpoint(d)

            @test IntervalSets.isclosedset(d)
            @test !IntervalSets.isopenset(d)
            @test IntervalSets.isleftclosed(d)
            @test !IntervalSets.isleftopen(d)
            @test !IntervalSets.isrightopen(d)
            @test IntervalSets.isrightclosed(d)

            @test convert(AbstractInterval, d) ≡ d
            @test convert(AbstractInterval{T}, d) ≡ d
            @test convert(IntervalSets.Domain, d) ≡ d
            @test convert(IntervalSets.Domain{T}, d) ≡ d

            d = OpenInterval(zero(T) .. one(T))
            @test IntervalSets.isopenset(d)
            @test !IntervalSets.isclosedset(d)
            @test IntervalSets.isopenset(d)
            @test !IntervalSets.isclosedset(d)
            @test !IntervalSets.isleftclosed(d)
            @test IntervalSets.isleftopen(d)
            @test IntervalSets.isrightopen(d)
            @test !IntervalSets.isrightclosed(d)
            @test leftendpoint(d) ∉ d
            @test BigFloat(leftendpoint(d)) ∉ d
            @test nextfloat(leftendpoint(d)) ∈ d
            @test nextfloat(BigFloat(leftendpoint(d))) ∈ d
            @test prevfloat(leftendpoint(d)) ∉ d
            @test prevfloat(leftendpoint(d)) ∉ d
            @test rightendpoint(d) ∉ d
            @test BigFloat(rightendpoint(d)) ∉ d
            @test nextfloat(rightendpoint(d)) ∉ d
            @test nextfloat(BigFloat(rightendpoint(d))) ∉ d
            @test prevfloat(rightendpoint(d)) ∈ d
            @test prevfloat(rightendpoint(d)) ∈ d
            @test infimum(d) == leftendpoint(d)
            @test supremum(d) == rightendpoint(d)
            @test_throws ArgumentError minimum(d)
            @test_throws ArgumentError maximum(d)

            @test isempty(OpenInterval(1,1))

            d = Interval{:open,:closed}(zero(T) .. one(T))
            @test !IntervalSets.isopenset(d)
            @test !IntervalSets.isclosedset(d)
            @test !IntervalSets.isleftclosed(d)
            @test IntervalSets.isleftopen(d)
            @test !IntervalSets.isrightopen(d)
            @test IntervalSets.isrightclosed(d)
            @test leftendpoint(d) ∉ d
            @test BigFloat(leftendpoint(d)) ∉ d
            @test nextfloat(leftendpoint(d)) ∈ d
            @test nextfloat(BigFloat(leftendpoint(d))) ∈ d
            @test prevfloat(leftendpoint(d)) ∉ d
            @test prevfloat(BigFloat(leftendpoint(d))) ∉ d
            @test rightendpoint(d) ∈ d
            @test BigFloat(rightendpoint(d)) ∈ d
            @test nextfloat(rightendpoint(d)) ∉ d
            @test nextfloat(BigFloat(rightendpoint(d))) ∉ d
            @test prevfloat(rightendpoint(d)) ∈ d
            @test prevfloat(BigFloat(rightendpoint(d))) ∈ d
            @test infimum(d) == leftendpoint(d)
            @test maximum(d) == supremum(d) == rightendpoint(d)
            @test_throws ArgumentError minimum(d)

            d = Interval{:closed,:open}(zero(T) .. one(T))
            @test !IntervalSets.isopenset(d)
            @test !IntervalSets.isclosedset(d)
            @test IntervalSets.isleftclosed(d)
            @test !IntervalSets.isleftopen(d)
            @test IntervalSets.isrightopen(d)
            @test !IntervalSets.isrightclosed(d)
            @test leftendpoint(d) ∈ d
            @test BigFloat(leftendpoint(d)) ∈ d
            @test nextfloat(leftendpoint(d)) ∈ d
            @test nextfloat(BigFloat(leftendpoint(d))) ∈ d
            @test prevfloat(leftendpoint(d)) ∉ d
            @test prevfloat(BigFloat(leftendpoint(d))) ∉ d
            @test rightendpoint(d) ∉ d
            @test BigFloat(rightendpoint(d)) ∉ d
            @test nextfloat(rightendpoint(d)) ∉ d
            @test nextfloat(BigFloat(rightendpoint(d))) ∉ d
            @test prevfloat(rightendpoint(d)) ∈ d
            @test prevfloat(BigFloat(rightendpoint(d))) ∈ d
            @test infimum(d) == minimum(d) == leftendpoint(d)
            @test supremum(d) == rightendpoint(d)
            @test_throws ArgumentError maximum(d)


            # - empty interval
            @test isempty(one(T) .. zero(T))
            @test zero(T) ∉ one(T) .. zero(T)

            d = one(T) .. zero(T)
            @test_throws ArgumentError minimum(d)
            @test_throws ArgumentError maximum(d)
            @test_throws ArgumentError infimum(d)
            @test_throws ArgumentError supremum(d)
        end
    end

    @testset "Issubset" begin
        I = 0..3
        J = 1..2
        @test J ⊆ I
        @test I ⊈ J
        @test OpenInterval(J) ⊆ I
        @test OpenInterval(I) ⊈ J
        @test J ⊆ OpenInterval(I)
        @test I ⊈ OpenInterval(J)
        @test OpenInterval(J) ⊆ OpenInterval(I)
        @test OpenInterval(I) ⊈ OpenInterval(J)
        @test Interval{:closed,:open}(J) ⊆ OpenInterval(I)
        @test Interval{:open,:closed}(J) ⊆ OpenInterval(I)
        @test Interval{:open,:closed}(J) ⊆ Interval{:open,:closed}(I)
        @test OpenInterval(I) ⊈ OpenInterval(J)

        @test Interval{:closed,:open}(J) ⊆ I
        @test I ⊈ Interval{:closed,:open}(J)


        @test I ⊆ I
        @test OpenInterval(I) ⊆ I
        @test Interval{:open,:closed}(I) ⊆ I
        @test Interval{:closed,:open}(I) ⊆ I
        @test I ⊈ OpenInterval(I)
        @test I ⊈ Interval{:open,:closed}(I)
        @test I ⊈ Interval{:closed,:open}(I)

        @test Interval{:closed,:open}(I) ⊆ Interval{:closed,:open}(I)
        @test Interval{:open,:closed}(I) ⊈ Interval{:closed,:open}(I)

        @test !isequal(I, OpenInterval(I))
        @test !(I == OpenInterval(I))
    end



    @testset "Union and intersection" begin
        for T in (Float32,Float64)
            # i1      0 ------>------ 1
            # i2         1/3 ->- 1/2
            # i3                 1/2 ------>------ 2
            # i4                                   2 -->-- 3
            # i5                        1.0+ -->-- 2
            # i_empty 0 ------<------ 1
            i1 = zero(T) .. one(T)
            i2 = one(T)/3 .. one(T)/2
            i3 = one(T)/2 .. 2*one(T)
            i4 = T(2) .. T(3)
            i5 = nextfloat(one(T)) .. 2one(T)
            i_empty = one(T) ..zero(T)

            # - union of completely overlapping intervals
            # i1      0 ------>------ 1
            # i2         1/3 ->- 1/2
            @test (@inferred i1 ∪ i2) ≡ (@inferred i2 ∪ i1) ≡ i1
            @test Interval{:open,:closed}(i1) ∪ Interval{:open,:closed}(i2) ≡
                  Interval{:open,:closed}(i2) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i1)
            @test Interval{:closed,:open}(i1) ∪ Interval{:closed,:open}(i2) ≡
                  Interval{:closed,:open}(i2) ∪ Interval{:closed,:open}(i1) ≡ Interval{:closed,:open}(i1)
            @test OpenInterval(i1) ∪ OpenInterval(i2) ≡
                    OpenInterval(i2) ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test i1 ∪ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(i2) ∪ i1 ≡ i1
            @test i1 ∪ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(i2) ∪ i1 ≡ i1
            @test i1 ∪ OpenInterval(i2) ≡ OpenInterval(i2) ∪ i1 ≡ i1
            @test OpenInterval(i1) ∪ i2 ≡ i2 ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test OpenInterval(i1) ∪ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(i2) ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test OpenInterval(i1) ∪ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(i2) ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test Interval{:open,:closed}(i1) ∪ OpenInterval(i2) ≡ OpenInterval(i2) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i1)
            @test Interval{:open,:closed}(i1) ∪ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(i2) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i1)

            # - intersection of completely overlapping intervals
            # i1      0 ------>------ 1
            # i2         1/3 ->- 1/2
            @test (@inferred i1 ∩ i2) ≡ (@inferred i2 ∩ i1) ≡ i2
            @test Interval{:open,:closed}(i1) ∩ Interval{:open,:closed}(i2) ≡
                  Interval{:open,:closed}(i2) ∩ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i2)
            @test Interval{:closed,:open}(i1) ∩ Interval{:closed,:open}(i2) ≡
                  Interval{:closed,:open}(i2) ∩ Interval{:closed,:open}(i1) ≡ Interval{:closed,:open}(i2)
            @test OpenInterval(i1) ∩ OpenInterval(i2) ≡
                    OpenInterval(i2) ∩ OpenInterval(i1) ≡ OpenInterval(i2)
            @test i1 ∩ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(i2) ∩ i1 ≡  Interval{:open,:closed}(i2)
            @test i1 ∩ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(i2) ∩ i1 ≡ Interval{:closed,:open}(i2)
            @test i1 ∩ OpenInterval(i2) ≡ OpenInterval(i2) ∩ i1 ≡ OpenInterval(i2)
            @test OpenInterval(i1) ∩ i2 ≡ i2 ∩ OpenInterval(i1) ≡ i2
            @test OpenInterval(i1) ∩ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(i2) ∩ OpenInterval(i1) ≡ Interval{:open,:closed}(i2)
            @test OpenInterval(i1) ∩ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(i2) ∩ OpenInterval(i1) ≡ Interval{:closed,:open}(i2)
            @test Interval{:open,:closed}(i1) ∩ OpenInterval(i2) ≡ OpenInterval(i2) ∩ Interval{:open,:closed}(i1) ≡ OpenInterval(i2)
            @test Interval{:open,:closed}(i1) ∩ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(i2) ∩ Interval{:open,:closed}(i1) ≡ Interval{:closed,:open}(i2)
            @test !isdisjoint(i1, i2)


            # - union of partially overlapping intervals
            # i1      0 ------>------ 1
            # i3                 1/2 ------>------ 2
            d = zero(T) .. 2*one(T)
            @test (@inferred i1 ∪ i3) ≡ (@inferred i3 ∪ i1) ≡ d
            @test Interval{:open,:closed}(i1) ∪ Interval{:open,:closed}(i3) ≡
                  Interval{:open,:closed}(i3) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(d)
            @test Interval{:closed,:open}(i1) ∪ Interval{:closed,:open}(i3) ≡
                  Interval{:closed,:open}(i3) ∪ Interval{:closed,:open}(i1) ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i1) ∪ OpenInterval(i3) ≡
                  OpenInterval(i3) ∪ OpenInterval(i1) ≡ OpenInterval(d)
            @test i1 ∪ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∪ i1 ≡ d
            @test i1 ∪ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∪ i1 ≡ Interval{:closed,:open}(d)
            @test i1 ∪ OpenInterval(i3) ≡ OpenInterval(i3) ∪ i1 ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i1) ∪ i3 ≡ i3 ∪ OpenInterval(i1) ≡ Interval{:open,:closed}(d)
            @test OpenInterval(i1) ∪ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∪ OpenInterval(i1) ≡ Interval{:open,:closed}(d)
            @test OpenInterval(i1) ∪ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∪ OpenInterval(i1) ≡ OpenInterval(d)
            @test Interval{:open,:closed}(i1) ∪ OpenInterval(i3) ≡ OpenInterval(i3) ∪ Interval{:open,:closed}(i1) ≡ OpenInterval(d)
            @test Interval{:open,:closed}(i1) ∪ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∪ Interval{:open,:closed}(i1) ≡ OpenInterval(d)

            # - intersection of partially overlapping intervals
            # i1      0 ------>------ 1
            # i3                 1/2 ------>------ 2
            d = one(T)/2 .. one(T)
            @test (@inferred i1 ∩ i3) ≡ (@inferred i3 ∩ i1) ≡ d
            @test Interval{:open,:closed}(i1) ∩ Interval{:open,:closed}(i3) ≡
                  Interval{:open,:closed}(i3) ∩ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(d)
            @test Interval{:closed,:open}(i1) ∩ Interval{:closed,:open}(i3) ≡
                  Interval{:closed,:open}(i3) ∩ Interval{:closed,:open}(i1) ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i1) ∩ OpenInterval(i3) ≡
                    OpenInterval(i3) ∩ OpenInterval(i1) ≡ OpenInterval(d)
            @test i1 ∩ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∩ i1 ≡ Interval{:open,:closed}(d)
            @test i1 ∩ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∩ i1 ≡ d
            @test i1 ∩ OpenInterval(i3) ≡ OpenInterval(i3) ∩ i1 ≡ Interval{:open,:closed}(d)
            @test OpenInterval(i1) ∩ i3 ≡ i3 ∩ OpenInterval(i1) ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i1) ∩ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∩ OpenInterval(i1) ≡ OpenInterval(d)
            @test OpenInterval(i1) ∩ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∩ OpenInterval(i1) ≡ Interval{:closed,:open}(d)
            @test Interval{:open,:closed}(i1) ∩ OpenInterval(i3) ≡ OpenInterval(i3) ∩ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(d)
            @test Interval{:open,:closed}(i1) ∩ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∩ Interval{:open,:closed}(i1) ≡ d
            @test !isdisjoint(i1, i3)


            # - union of barely overlapping intervals
            # i2         1/3 ->- 1/2
            # i3                 1/2 ------>------ 2
            d = one(T)/3 .. 2*one(T)
            @test (@inferred i2 ∪ i3) ≡ (@inferred i3 ∪ i2) ≡ d
            @test Interval{:open,:closed}(i2) ∪ Interval{:open,:closed}(i3) ≡
                  Interval{:open,:closed}(i3) ∪ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(d)
            @test Interval{:closed,:open}(i2) ∪ Interval{:closed,:open}(i3) ≡
                  Interval{:closed,:open}(i3) ∪ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(d)
            @test_throws ArgumentError OpenInterval(i2) ∪ OpenInterval(i3)
            @test i2 ∪ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∪ i2 ≡ d
            @test i2 ∪ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∪ i2 ≡ Interval{:closed,:open}(d)
            @test i2 ∪ OpenInterval(i3) ≡ OpenInterval(i3) ∪ i2 ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i2) ∪ i3 ≡ i3 ∪ OpenInterval(i2) ≡ Interval{:open,:closed}(d)
            @test_throws ArgumentError OpenInterval(i2) ∪ Interval{:open,:closed}(i3)
            @test Interval{:open,:closed}(i2) ∪ OpenInterval(i3) ≡ OpenInterval(i3) ∪ Interval{:open,:closed}(i2) ≡ OpenInterval(d)
            @test Interval{:open,:closed}(i2) ∪ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∪ Interval{:open,:closed}(i2) ≡ OpenInterval(d)

            # - intersection of barely overlapping intervals
            # i2         1/3 ->- 1/2
            # i3                 1/2 ------>------ 2
            d = one(T)/2 .. one(T)/2
            @test (@inferred i2 ∩ i3) ≡ (@inferred i3 ∩ i2) ≡ d
            @test Interval{:open,:closed}(i2) ∩ Interval{:open,:closed}(i3) ≡
                  Interval{:open,:closed}(i3) ∩ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(d)
            @test Interval{:closed,:open}(i2) ∩ Interval{:closed,:open}(i3) ≡
                  Interval{:closed,:open}(i3) ∩ Interval{:closed,:open}(i2) ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i2) ∩ OpenInterval(i3) ≡
                    OpenInterval(i3) ∩ OpenInterval(i2) ≡ OpenInterval(d)
            @test i2 ∩ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∩ i2 ≡ Interval{:open,:closed}(d)
            @test i2 ∩ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∩ i2 ≡ d
            @test i2 ∩ OpenInterval(i3) ≡ OpenInterval(i3) ∩ i2 ≡ Interval{:open,:closed}(d)
            @test OpenInterval(i2) ∩ i3 ≡ i3 ∩ OpenInterval(i2) ≡ Interval{:closed,:open}(d)
            @test OpenInterval(i2) ∩ Interval{:open,:closed}(i3) ≡ Interval{:open,:closed}(i3) ∩ OpenInterval(i2) ≡ OpenInterval(d)
            @test OpenInterval(i2) ∩ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∩ OpenInterval(i2) ≡ Interval{:closed,:open}(d)
            @test Interval{:open,:closed}(i2) ∩ OpenInterval(i3) ≡ OpenInterval(i3) ∩ Interval{:open,:closed}(i2) ≡ Interval{:open,:closed}(d)
            @test Interval{:open,:closed}(i2) ∩ Interval{:closed,:open}(i3) ≡ Interval{:closed,:open}(i3) ∩ Interval{:open,:closed}(i2) ≡ d

            # - intersection of custom intervals
            @test intersect(MyUnitInterval(true,true), MyUnitInterval(false,false)) == OpenInterval(0,1)
            @test intersect(MyUnitInterval(true,true), OpenInterval(0,1)) == OpenInterval(0,1)

            # - union of non-overlapping intervals
            # i1      0 ------>------ 1
            # i4                                   2 -->-- 3
            @test_throws ArgumentError i1 ∪ i4
            @test_throws ArgumentError i4 ∪ i1
            @test_throws ArgumentError OpenInterval(i1) ∪ i4
            @test_throws ArgumentError i1 ∪ OpenInterval(i4)
            @test_throws ArgumentError Interval{:closed,:open}(i1) ∪ i4
            @test_throws ArgumentError Interval{:closed,:open}(i1) ∪ OpenInterval(i4)

            # - union of almost-overlapping intervals
            # i1      0 ------>------ 1
            # i5                        1.0+ -->-- 2
            @test_throws ArgumentError i1 ∪ i5
            @test_throws ArgumentError i5 ∪ i1
            @test_throws ArgumentError OpenInterval(i1) ∪ i5
            @test_throws ArgumentError i1 ∪ OpenInterval(i5)
            @test_throws ArgumentError Interval{:closed,:open}(i1) ∪ i5
            @test_throws ArgumentError Interval{:closed,:open}(i1) ∪ OpenInterval(i5)

            # - intersection of non-overlapping intervals
            # i1      0 ------>------ 1
            # i4                                   2 -->-- 3
            @test isempty(i1 ∩ i4)
            @test isempty(i4 ∩ i1)
            @test isempty(OpenInterval(i1) ∩ i4)
            @test isempty(i1 ∩ OpenInterval(i4))
            @test isempty(Interval{:closed,:open}(i1) ∩ i4)
            @test isdisjoint(i1, i4)
            @test isdisjoint(i4, i1)
            @test isdisjoint(OpenInterval(i1), i4)
            @test isdisjoint(i1, OpenInterval(i4))
            @test isdisjoint(Interval{:closed,:open}(i1), i4)


            # - intersection of almost-overlapping intervals
            # i1      0 ------>------ 1
            # i5                        1.0+ -->-- 2
            @test isempty(i1 ∩ i5)
            @test isempty(i5 ∩ i1)
            @test isempty(OpenInterval(i1) ∩ i5)
            @test isempty(i1 ∩ OpenInterval(i5))
            @test isempty(Interval{:closed,:open}(i1) ∩ i5)
            @test isdisjoint(i1, i5)
            @test isdisjoint(i5, i1)
            @test isdisjoint(OpenInterval(i1), i5)
            @test isdisjoint(i1, OpenInterval(i5))
            @test isdisjoint(Interval{:closed,:open}(i1), i5)

            # - union of interval with empty
            # i1      0 ------>------ 1
            # i_empty 0 ------<------ 1
            @test i1 ∪ i_empty ≡ i_empty ∪ i1 ≡ i1
            @test Interval{:open,:closed}(i1) ∪ Interval{:open,:closed}(i_empty) ≡
                  Interval{:open,:closed}(i_empty) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i1)
            @test Interval{:closed,:open}(i1) ∪ Interval{:closed,:open}(i_empty) ≡
                  Interval{:closed,:open}(i_empty) ∪ Interval{:closed,:open}(i1) ≡ Interval{:closed,:open}(i1)
            @test OpenInterval(i1) ∪ OpenInterval(i_empty) ≡
                    OpenInterval(i_empty) ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test i1 ∪ Interval{:open,:closed}(i_empty) ≡ Interval{:open,:closed}(i_empty) ∪ i1 ≡ i1
            @test i1 ∪ Interval{:closed,:open}(i_empty) ≡ Interval{:closed,:open}(i_empty) ∪ i1 ≡ i1
            @test i1 ∪ OpenInterval(i_empty) ≡ OpenInterval(i_empty) ∪ i1 ≡ i1
            @test OpenInterval(i1) ∪ i_empty ≡ i_empty ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test OpenInterval(i1) ∪ Interval{:open,:closed}(i_empty) ≡ Interval{:open,:closed}(i_empty) ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test OpenInterval(i1) ∪ Interval{:closed,:open}(i_empty) ≡ Interval{:closed,:open}(i_empty) ∪ OpenInterval(i1) ≡ OpenInterval(i1)
            @test Interval{:open,:closed}(i1) ∪ OpenInterval(i_empty) ≡ OpenInterval(i_empty) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i1)
            @test Interval{:open,:closed}(i1) ∪ Interval{:closed,:open}(i_empty) ≡ Interval{:closed,:open}(i_empty) ∪ Interval{:open,:closed}(i1) ≡ Interval{:open,:closed}(i1)

            # - intersection of interval with empty
            # i1      0 ------>------ 1
            # i_empty 0 ------<------ 1
            @test isempty(i1 ∩ i_empty)
            @test isempty(i_empty ∩ i1)
            @test isempty(OpenInterval(i1) ∩ i_empty)
            @test isempty(i1 ∩ OpenInterval(i_empty))
            @test isempty(Interval{:closed,:open}(i1) ∩ i_empty)
            @test isdisjoint(i1, i_empty)
            @test isdisjoint(i_empty, i1)
            @test isdisjoint(OpenInterval(i1), i_empty)
            @test isdisjoint(i1, OpenInterval(i_empty))
            @test isdisjoint(Interval{:closed,:open}(i1), i_empty)

            # - test matching endpoints
            @test (0..1) ∪ OpenInterval(0..1) ≡ OpenInterval(0..1) ∪ (0..1) ≡  0..1
            @test Interval{:open,:closed}(0..1) ∪ OpenInterval(0..1) ≡
                    OpenInterval(0..1) ∪ Interval{:open,:closed}(0..1) ≡
                    Interval{:open,:closed}(0..1)
            @test Interval{:closed,:open}(0..1) ∪ OpenInterval(0..1) ≡
                    OpenInterval(0..1) ∪ Interval{:closed,:open}(0..1) ≡
                    Interval{:closed,:open}(0..1)

            # - different interval types
            @test (1..2) ∩ OpenInterval(0.5, 1.5) ≡ Interval{:closed, :open}(1, 1.5)
            @test (1..2) ∪ OpenInterval(0.5, 1.5) ≡ Interval{:open, :closed}(0.5, 2)
        end
    end

    @testset "Empty" begin
        for T in (Float32,Float64)
            @test isempty(Interval{:open,:open}(zero(T),zero(T)))
            @test zero(T) ∉ Interval{:open,:open}(zero(T),zero(T))
            @test isempty(Interval{:open,:closed}(zero(T),zero(T)))
            @test zero(T) ∉ Interval{:open,:closed}(zero(T),zero(T))
            @test isempty(Interval{:closed,:open}(zero(T),zero(T)))
            @test zero(T) ∉ Interval{:closed,:open}(zero(T),zero(T))
        end
    end

    @testset "Custom intervals" begin
        I = MyUnitInterval(true,true)
        @test eltype(I) == eltype(typeof(I)) == Int
        @test leftendpoint(I) == 0
        @test rightendpoint(I) == 1
        @test isleftclosed(I)
        @test !isleftopen(I)
        @test isrightclosed(I)
        @test !isrightopen(I)
        @test ClosedInterval(I) === convert(ClosedInterval, I) ===
                ClosedInterval{Int}(I) === convert(ClosedInterval{Int}, I)  ===
                convert(Interval, I) === Interval(I) === 0..1
        @test_throws InexactError convert(OpenInterval, I)
        I = MyUnitInterval(false,false)
        @test leftendpoint(I) == 0
        @test rightendpoint(I) == 1
        @test !isleftclosed(I)
        @test !isrightclosed(I)
        @test OpenInterval(I) === convert(OpenInterval, I) ===
                OpenInterval{Int}(I) === convert(OpenInterval{Int}, I)  ===
                convert(Interval, I) === Interval(I) === OpenInterval(0..1)
        I = MyUnitInterval(false,true)
        @test leftendpoint(I) == 0
        @test rightendpoint(I) == 1
        @test isleftclosed(I) == false
        @test isrightclosed(I) == true
        @test Interval{:open,:closed}(I) === convert(Interval{:open,:closed}, I) ===
                Interval{:open,:closed,Int}(I) === convert(Interval{:open,:closed,Int}, I)  ===
                convert(Interval, I) === Interval(I) === Interval{:open,:closed}(0..1)
        I = MyUnitInterval(true,false)
        @test leftendpoint(I) == 0
        @test rightendpoint(I) == 1
        @test isleftclosed(I) == true
        @test isrightclosed(I) == false
        @test Interval{:closed,:open}(I) === convert(Interval{:closed,:open}, I) ===
                Interval{:closed,:open,Int}(I) === convert(Interval{:closed,:open,Int}, I)  ===
                convert(Interval, I) === Interval(I) === Interval{:closed,:open}(0..1)
        @test convert(AbstractInterval, I) === convert(AbstractInterval{Int}, I) === I
    end

    @testset "Custom typed endpoints interval" begin
        I = MyClosedUnitInterval()
        @test leftendpoint(I) == 0
        @test rightendpoint(I) == 1
        @test isleftclosed(I) == true
        @test isrightclosed(I) == true
        @test ClosedInterval(I) === convert(ClosedInterval, I) ===
                ClosedInterval{Int}(I) === convert(ClosedInterval{Int}, I)  ===
                convert(Interval, I) === Interval(I) === 0..1
        @test_throws InexactError convert(OpenInterval, I)
        @test I ∩ I === 0..1
        @test I ∩ (0.0..0.5) === 0.0..0.5
    end

    @testset "in" begin
        @test in(0.1, 0.0..1.0) == true
        @test in(0.0, 0.0..1.0) == true
        @test in(1.1, 0.0..1.0) == false
        @test in(0.0, nextfloat(0.0)..1.0) == false
    end

    @testset "issubset" begin
        @test issubset(Interval{:closed,:closed}(1,2), Interval{:closed,:closed}(1,2)) == true
        @test issubset(Interval{:closed,:closed}(1,2), Interval{:open  ,:open  }(1,2)) == false
        @test issubset(Interval{:closed,:open  }(1,2), Interval{:open  ,:open  }(1,2)) == false
        @test issubset(Interval{:open  ,:closed}(1,2), Interval{:open  ,:open  }(1,2)) == false
        @test issubset(Interval{:closed,:closed}(1,2), Interval{:closed,:closed}(1,prevfloat(2.0))) == false
        @test issubset(Interval{:closed,:open  }(1,2), Interval{:open  ,:open  }(prevfloat(1.0),2)) == true
    end

    @testset "missing in" begin
        @test ismissing(missing in 0..1)
        @test !(missing in 1..0)
        @test ismissing(missing in OpenInterval(0, 1))
        @test ismissing(missing in Interval{:closed, :open}(0, 1))
        @test ismissing(missing in Interval{:open, :closed}(0, 1))
    end

    @testset "complex in" begin
        @test 0+im ∉ 0..2
        @test 0+0im ∈ 0..2
        @test 0+eps()im ∉ 0..2

        @test 0+im ∉ OpenInterval(0,2)
        @test 0+0im ∉ OpenInterval(0,2)
        @test 1+0im ∈ OpenInterval(0,2)
        @test 1+eps()im ∉ OpenInterval(0,2)

        @test 0+im ∉ Interval{:closed,:open}(0,2)
        @test 0+0im ∈ Interval{:closed,:open}(0,2)
        @test 1+0im ∈ Interval{:closed,:open}(0,2)
        @test 1+eps()im ∉ Interval{:closed,:open}(0,2)

        @test 0+im ∉ Interval{:open,:closed}(0,2)
        @test 0+0im ∉ Interval{:open,:closed}(0,2)
        @test 1+0im ∈ Interval{:open,:closed}(0,2)
        @test 1+eps()im ∉ Interval{:open,:closed}(0,2)
    end

    @testset "closedendpoints" begin
        @test closedendpoints(0..1) == closedendpoints(MyClosedUnitInterval()) == (true,true)
        @test closedendpoints(Interval{:open,:closed}(0,1)) == (false,true)
        @test closedendpoints(Interval{:closed,:open}(0,1)) == (true,false)
        @test closedendpoints(OpenInterval(0,1)) == (false,false)
    end

    @testset "OneTo" begin
        @test_throws ArgumentError Base.OneTo{Int}(0..5)
        @test_throws ArgumentError Base.OneTo(0..5)
        @test Base.OneTo(1..5) == Base.OneTo{Int}(1..5) == Base.OneTo(5)
        @test Base.Slice(1..5) == Base.Slice{UnitRange{Int}}(1..5) == Base.Slice(1:5)
    end

    @testset "range" begin
        @test range(0..1, 10) == range(0; stop=1, length=10)
        @test range(0..1; length=10) == range(0; stop=1, length=10)
        @test range(0..1; step=1/10) == range(0; stop=1, step=1/10)
        @test range(Interval{:closed,:open}(0..1), 10) == range(0; step=1/10, length=10)
        @test range(Interval{:closed,:open}(0..1); length=10) == range(0; step=1/10, length=10)
    end

    @testset "clamp" begin
        @test clamp(1, 0..3) == 1
        @test clamp(1.0, 1.5..3) == 1.5
        @test clamp(1.0, 0..0.5) == 0.5
        @test clamp.([pi, 1.0, big(10.)], Ref(2..9.)) == [big(pi), 2, 9]
    end

    @testset "mod" begin
        @test mod(10, 0..3) === 1
        @test mod(-10, 0..3) === 2
        @test mod(10.5, 0..3) == 1.5
        @test mod(10.5, 1..1) |> isnan
        @test mod(10.5, Interval{:open, :open}(0, 3)) == 1.5
        @test mod(10.5, Interval{:open, :open}(1, 1)) |> isnan

        @test_throws DomainError mod(0, Interval{:open, :open}(0, 3))
        for x in (0, 3, 0.0, -0.0, 3.0, -eps())
            @test mod(x, Interval{:closed, :open}(0, 3))::typeof(x) == 0
            @test mod(x, Interval{:open, :closed}(0, 3))::typeof(x) == 3
        end
    end

    @testset "rand" begin
        @test rand(1..2) isa Float64
        @test rand(1..2.) isa Float64
        @test rand(1..big(2)) isa BigFloat
        @test rand(1..(3//2)) isa Float64
        @test rand(Int32(1)..Int32(2)) isa Float64
        @test rand(Float32(1)..Float32(2)) isa Float32
        @test_throws ArgumentError rand(2..1)

        i1 = 1..2
        i2 = 3e100..3e100
        i3 = 1..typemax(Float64)
        i4 = typemin(Float64)..typemax(Float64)
        i5 = typemin(Float64)..1
        for _ in 1:100
            rand(i1) in i1
            rand(i2) in i2
            rand(i3) in i3
            rand(i4) in i4
            rand(i5) in i5
            rand(i1,10) ⊆ i1
            rand(i2,10) ⊆ i2
            rand(i3,10) ⊆ i3
            rand(i4,10) ⊆ i4
            rand(i5,10) ⊆ i5
        end

        # special test to catch issue mentioned at the end of https://github.com/JuliaApproximation/DomainSets.jl/pull/112
        struct RandTestUnitInterval <: TypedEndpointsInterval{:closed, :closed, Float64} end
        IntervalSets.endpoints(::RandTestUnitInterval) = (-1.0, 1.0)
        @test rand(RandTestUnitInterval()) in -1.0..1.0
    end

    @testset "IteratorSize" begin
        @test Base.IteratorSize(ClosedInterval) == Base.SizeUnknown()
    end

    @testset "IncompleteInterval" begin
        I = IncompleteInterval()
        @test eltype(I) === Int
        @test_throws ErrorException endpoints(I)
        @test_throws ErrorException closedendpoints(I)
        @test_throws MethodError 2 in I
    end

    @testset "float" begin
        i1 = 1..2
        @test i1 isa ClosedInterval{Int}
        @test float(i1) isa ClosedInterval{Float64}
        @test float(i1) == i1
        i2 = big(1)..2
        @test i2 isa ClosedInterval{BigInt}
        @test float(i2) isa ClosedInterval{BigFloat}
        @test float(i2) == i2
        i3 = OpenInterval(1,2)
        @test i3 isa OpenInterval{Int}
        @test float(i3) isa OpenInterval{Float64}
        @test float(i3) == i3
        i4 = OpenInterval(1.,2.)
        @test i4 isa OpenInterval{Float64}
        @test float(i4) isa OpenInterval{Float64}
        @test float(i4) == i4
    end

    include("findall.jl")
end
