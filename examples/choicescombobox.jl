using Bonito
using Observables
# Example usage function
options = Observable(["Banana", "Apple", "Cherry", "Date", "Elderberry", "Fig", "Grape"])

App() do
    # Create a combo box with some sample options
    combobox = ChoicesComboBox(options;
        #initial_value="not set...",
        allow_search=true,
        itemSelectText = "selectme"
    )

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
