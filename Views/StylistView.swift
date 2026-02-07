// StylistView.swift
// Main container for the AI Stylist feature

import SwiftUI
import SwiftData

struct StylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.dateAdded, order: .reverse) private var items: [ClothingItem]
    
    @State private var selectedItems: Set<UUID> = []
    @State private var showingSelection = true
    @State private var modelGender: Gender = .female
    
    enum Gender {
        case male, female
    }
    
    var body: some View {
        ZStack {
            PoshTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Styling Canvas
                StylingCanvasView(
                    selectedItems: items.filter { selectedItems.contains($0.id) },
                    gender: modelGender
                )
                .frame(maxHeight: .infinity)
                
                // Bottom Selection Drawer/Grid
                VStack(spacing: 0) {
                    Divider()
                        .background(PoshTheme.Colors.secondaryAccent.opacity(0.3))
                    
                    
                    HStack {
                        HStack(spacing: 6) {
                            Text("YOUR CLOSET")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(PoshTheme.Colors.secondaryAccent.opacity(0.6))
                            
                            if !selectedItems.isEmpty {
                                Text("(\(selectedItems.count))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(PoshTheme.Colors.primaryAccentStart)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring()) {
                                showingSelection.toggle()
                            }
                        } label: {
                            Image(systemName: showingSelection ? "chevron.down" : "chevron.up")
                                .foregroundColor(PoshTheme.Colors.secondaryAccent)
                        }
                    }
                    .padding()
                    .background(PoshTheme.Colors.cardBackground.opacity(0.5))
                    
                    if showingSelection {
                        ItemSelectionGridView(
                            items: items,
                            selectedItems: $selectedItems
                        )
                        .transition(.move(edge: .bottom))
                        .frame(maxHeight: 350)
                    }
                }
                .background(.ultraThinMaterial)
                .poshCard()
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("AI STYLIST").poshHeadline(size: 18)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Female Model") { modelGender = .female }
                    Button("Male Model") { modelGender = .male }
                } label: {
                    Image(systemName: "person.2")
                        .foregroundColor(PoshTheme.Colors.secondaryAccent)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StylistView()
    }
    .modelContainer(for: [ClothingItem.self, Category.self], inMemory: true)
}
