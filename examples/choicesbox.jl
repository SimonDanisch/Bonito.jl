using Bonito
using Observables
# Example usage function

App() do
    # sample options
    fruits = ["Cherry", "Apple", "Banana", "Date", "Elderberry",  "Fig", "Grape"]

    # Configure Choices.js parameters
    params = ChoicesJSParams(
        searchPlaceholderValue="Type to search fruits...",
        itemSelectText= "Press this fruit to select",
        searchEnabled=true,
        shouldSort=false,
        searchResultLimit=3,
        renderChoiceLimit=10,
        placeholder = true,
        placeholderValue = "--"
    )
    choicesbox = ChoicesBox(fruits; choicejsparams=params)

    # Display selected value
    selected_display = map(choicesbox.value) do value
        "Selected: $value"
    end

    # Handle value changes
    on(choicesbox.value) do value
        @info "ChoicesBox value changed to: $value"
    end
    return Card(
        DOM.div(
        DOM.h2("ChoicesBox Example"),
        DOM.p("This box allows you to select from predefined option list:"),
        choicesbox,
        DOM.p(selected_display, style="margin-top: 20px; font-weight: bold;");
        )
    )
end
