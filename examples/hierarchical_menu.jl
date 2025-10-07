using Bonito

App() do
    menu_items = [
        HierarchicalMenuItem("Home", "home"; icon="🏠"),
        HierarchicalSubMenu("File", [
            HierarchicalMenuItem("New", "file_new"; icon="📄"),
            HierarchicalMenuItem("Open", "file_open"; icon="📂"),
            HierarchicalMenuItem("Save", "file_save"; icon="💾"),
            HierarchicalSubMenu("Recent", [
                HierarchicalMenuItem("Document 1", "recent_doc1"),
                HierarchicalMenuItem("Document 2", "recent_doc2")
            ])
        ]; icon="📁"),
        HierarchicalSubMenu("Edit", [
            HierarchicalMenuItem("Cut", "edit_cut"; icon="✂️"),
            HierarchicalMenuItem("Copy", "edit_copy"; icon="📋"),
            HierarchicalMenuItem("Paste", "edit_paste"; icon="📌")
        ]; icon="✏️"),
        HierarchicalMenuItem("Settings", "settings"; icon="⚙️")
    ]

    menu = HierarchicalMenu(menu_items)
    on(menu.selected_value) do value
        @info "Selected: $value"
    end
    return Card(menu)
end
