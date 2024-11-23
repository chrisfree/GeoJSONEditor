struct CustomListRowStyle: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .listRowBackground(
                isSelected ? 
                    Color(NSColor.unemphasizedSelectedContentBackgroundColor).opacity(0.5) : 
                    Color(NSColor.alternatingContentBackgroundColors[1])
            )
    }
}
