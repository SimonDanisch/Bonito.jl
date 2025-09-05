using Bonito
using Observables
# Example usage function

App() do
    # Create a combo box with some sample options
    fruits = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]

    # Configure Choices.js parameters
    params = ChoicesJSParams(
        searchPlaceholderValue="Type to search fruits...",
        itemSelectText= "Press this fruit to select",
        searchEnabled=true,
        shouldSort=true,
        searchResultLimit=5
    )
    combobox = ChoicesComboBox(fruits; choicejsparams=params)

    # Display selected value
    selected_display = map(combobox.value) do value
        isempty(value) ? "No selection" : "Selected: $value"
    end

    # Handle value changes
    on(combobox.value) do value
        @info "ComboBox value changed to: $value"
    end

    return DOM.div(
        DOM.h2("Choices.js ComboBox Example"),
        DOM.p("This combo box allows you to select from predefined options or type your own:"),
        combobox,
        DOM.p(selected_display, style="margin-top: 20px; font-weight: bold;")
    )
end
