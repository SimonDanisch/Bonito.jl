using Bonito, Test

@testset "bounded application event admission" begin
    budget = Bonito.MessageBudget("page", 2)
    @test Bonito.admit_message!(budget, 1)
    @test Bonito.admit_message!(budget, 2)
    @test_throws "capacity" Bonito.admit_message!(budget, 3)
    @test Bonito.message_budget(budget).received == 2
    Bonito.release_message!(budget, 1)
    @test Bonito.admit_message!(budget, 3)
    @test !Bonito.admit_message!(budget, 2)
    @test_throws "order" Bonito.release_message!(budget, 3)
    @test_throws "gap" Bonito.admit_message!(budget, 5)
    @test Bonito.message_budget(budget) == (owner="page", capacity=2, received=3, released=1)
    Bonito.release_message!(budget, 2)
    Bonito.release_message!(budget, 3)
    @test Bonito.message_budget(budget).received == Bonito.message_budget(budget).released

    # Credits are cumulative, so a burst shares them. The last release always reports.
    burst = Bonito.MessageBudget("page", 8)
    foreach(sequence -> Bonito.admit_message!(burst, sequence), 1:8)
    due = map(1:8) do sequence
        Bonito.release_message!(burst, sequence)
        Bonito.credit_due!(burst, sequence == 8)
    end
    @test due == [false, true, false, true, false, true, false, true]
    @test !Bonito.credit_due!(burst, false)
end
