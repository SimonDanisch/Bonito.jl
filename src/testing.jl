###
## Testing functions / macros for web stuff!
###

"""
    wait_test(condition)
Waits for condition expression to become true and then tests it!
"""
macro wait_test(condition)
    return quote
        while !$(esc(condition))
            sleep(0.001)
        end
        @test $(condition)
    end
end
