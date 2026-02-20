import SwiftUI

struct OutfitTearSheet: View {
    let heroImage: UIImage
    let cutoutImages: [UIImage]
    let title: String
    
    var body: some View {
        ZStack {
            // Background texture (Matt / Art Paper feel)
            Color(red: 0.98, green: 0.976, blue: 0.965)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header (Elegant Typography)
                HStack(alignment: .bottom) {
                    Text("THE EDIT")
                        .font(.system(size: 36, weight: .light))
                        .tracking(10)
                        .foregroundColor(.black.opacity(0.85))
                    
                    Spacer()
                    
                    Text(title)
                        .font(.custom("Georgia-Italic", size: 32))
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(.horizontal, 56)
                .padding(.top, 80)
                .padding(.bottom, 40)
                
                // Hero Image (Physical photo placed on paper)
                Image(uiImage: heroImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 900, height: 1920 * 0.50)
                    .clipped()
                    .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 16)
                    .padding(.bottom, 20)
                
                // The Cutouts (Organically placed floating items)
                GeometryReader { geo in
                    let count = cutoutImages.count == 0 ? 1 : cutoutImages.count
                    let itemsPerRow = count > 4 ? 3 : (count == 4 ? 2 : count)
                    let totalRows = Int(ceil(Double(count) / Double(itemsPerRow)))
                    
                    ZStack {
                        ForEach(Array(cutoutImages.enumerated()), id: \.offset) { index, image in
                            let row = index / itemsPerRow
                            let col = index % itemsPerRow
                            
                            // Center rows that have fewer items (e.g. 5 items -> Row 1 has 3, Row 2 has 2)
                            let itemsInThisRow = (row == totalRows - 1) ? (count - (row * itemsPerRow)) : itemsPerRow
                            
                            let cellWidth = geo.size.width / CGFloat(itemsInThisRow)
                            let cellHeight = geo.size.height / CGFloat(totalRows)
                            
                            let xPosition = (CGFloat(col) * cellWidth) + (cellWidth / 2) - (geo.size.width / 2)
                            let yPosition = (CGFloat(row) * cellHeight) + (cellHeight / 2) - (geo.size.height / 2)
                            
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    maxWidth: min(cellWidth * 1.1, 380),
                                    maxHeight: min(cellHeight * 1.1, 420)
                                )
                                .rotationEffect(.degrees(Double.random(in: -6...6)))
                                .offset(
                                    x: xPosition + CGFloat.random(in: -15...15),
                                    y: yPosition + CGFloat.random(in: -15...15)
                                )
                                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 48)
                
                // Footer
                HStack {
                    Text("curated on threadlist")
                        .font(.custom("Georgia", size: 20))
                        .tracking(2)
                        .foregroundColor(.black.opacity(0.6))
                    
                    Spacer()
                    
                    Text(Date().formatted(.dateTime.day().month().year()))
                        .font(.system(size: 16, weight: .light))
                        .tracking(3)
                        .foregroundColor(.black.opacity(0.5))
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920) // Standard 9:16 high-res aspect ratio
    }
}

#Preview {
    OutfitTearSheet(
        heroImage: UIImage(systemName: "person.crop.rectangle.fill")!,
        cutoutImages: [
            UIImage(systemName: "tshirt")!,
            UIImage(systemName: "shoe")!
        ],
        title: "Daily Look".uppercased()
    )
}
