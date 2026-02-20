import SwiftUI

struct TearSheetPreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PoshTheme.Colors.canvas.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 16)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                            Text("SHARE TO SOCIALS")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .poshButton()
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("The Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(PoshTheme.Colors.gold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [image])
                    .presentationDetents([.medium, .large])
            }
        }
    }
}
