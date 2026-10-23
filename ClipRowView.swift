import SwiftUI

struct ClipRowView: View {
    let clip: DashcamClip
    var onDelete: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnailView
               
                .frame(width: 92, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 5) {
                if clip.isProtected {
                    Text("SAVED")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.8)
                        .foregroundColor(Color(red: 1, green: 0.42, blue: 0.42))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.2)))
                }

                Text(clip.dateText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    if let durationText = clip.durationText {
                        Text(durationText)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.65))

                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Text(clip.sizeText)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ShareLink(item: clip.url) {
                    iconCircle("square.and.arrow.up", tint: .white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDelete()
                }) {
                    iconCircle("trash", tint: Color(red: 1, green: 0.42, blue: 0.42))
                }
                .buttonStyle(.plain)
            }
            .fixedSize()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
        .task(id: clip.id) {
          
            thumbnail = await ClipThumbnailGenerator.thumbnail(for: clip.url)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Color.white.opacity(0.08)

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "film")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.25))
                }
            }

            if let durationText = clip.durationText {
                Text(durationText)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(5)
            }
        }
    }

    private func iconCircle(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(tint)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Color.white.opacity(0.09)))
    }
}

