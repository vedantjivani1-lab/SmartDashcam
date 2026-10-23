import SwiftUI
struct ClipListView: View {
    var activeSegmentURL: URL? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var protectedClips: [DashcamClip] = []
    @State private var loopClips: [DashcamClip] = []
    @State private var playingClip: DashcamClip?
    @State private var clipPendingDelete: DashcamClip?
    @State private var isLoading = true

    @State private var loopUsedBytes: Int64 = 0
    @State private var protectedUsedBytes: Int64 = 0
    @State private var remainingHours: Double?

    @State private var searchText = ""
    @State private var activeFilter: ClipFilter = .all
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool

    @State private var showCalendar = false
    @State private var selectedDate: Date?

    @State private var groupByDrive = true

    @State private var expandedSessions: Set<String> = []
    @State private var didAutoExpand = false

    @State private var isSelecting = false
    @State private var selectedClipIDs: Set<String> = []

    private enum ClipFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case saved = "Saved"
        case today = "Today"
        case week = "This week"
        var id: String { rawValue }
    }

    private var hasAnyClips: Bool { !protectedClips.isEmpty || !loopClips.isEmpty }

    private var filteredLoop: [DashcamClip] { apply(to: loopClips) }
    private var filteredProtected: [DashcamClip] { apply(to: protectedClips) }

    private var hasVisibleResults: Bool {
        !filteredLoop.isEmpty || !filteredProtected.isEmpty
    }

    private var isFiltering: Bool {
        !searchText.isEmpty || activeFilter != .all || selectedDate != nil
    }

   
    private var driveSessions: [DriveSession] {
        DriveSession.group(filteredLoop)
    }

    private var showingDrives: Bool {
        groupByDrive && !isFiltering
    }

    private var earliestClipDate: Date {
        (protectedClips + loopClips).map(\.modifiedAt).min() ?? Date()
    }

    private var visibleClipIDs: Set<String> {
        Set((filteredLoop + filteredProtected).map(\.id))
    }

    private var selectedClips: [DashcamClip] {
        (loopClips + protectedClips).filter { selectedClipIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if isLoading {
                        loadingState
                    } else if !hasAnyClips {
                        emptyState
                    } else {
                        if showSearch { searchBar }
                        filterRow

                        if let selectedDate {
                            selectedDateChip(selectedDate)
                        }

                        if !isFiltering && !isSelecting {
                            storageCard
                        }

                        if !hasVisibleResults {
                            noMatchesState
                        }
                    }

                    if !filteredLoop.isEmpty {
                        if showingDrives {
                            driveSection
                        } else {
                            section(
                                title: "RECENT RECORDING",
                                subtitle: "Auto-deletes oldest first when storage fills",
                                count: filteredLoop.count,
                                clips: filteredLoop
                            )
                        }
                    }

                    if !filteredProtected.isEmpty {
                        section(
                            title: "SAVED / CRASH CLIPS",
                            subtitle: "Kept permanently until you delete them",
                            count: filteredProtected.count,
                            clips: filteredProtected
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, isSelecting ? 110 : 32)
            }
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if isSelecting { selectionBar }
            }
            .navigationTitle(isSelecting ? "\(selectedClipIDs.count) selected" : "My Clips")
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
            .refreshable { await reload() }
            .task { await reload() }
            .fullScreenCover(item: $playingClip) { clip in
                ClipPlayerView(url: clip.url)
            }
            .sheet(isPresented: $showCalendar) { calendarSheet }
            .confirmationDialog(
                "Delete this clip? This can't be undone.",
                isPresented: Binding(
                    get: { clipPendingDelete != nil },
                    set: { if !$0 { clipPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Clip", role: .destructive) {
                    if let clip = clipPendingDelete {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        deleteSingle(clip)
                    }
                    clipPendingDelete = nil
                }
                Button("Cancel", role: .cancel) { clipPendingDelete = nil }
            }
        }
        .preferredColorScheme(.dark)
    }

    

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isSelecting {
                Button("Cancel") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelecting = false
                        selectedClipIDs = []
                    }
                }
                .font(.system(size: 15))
            } else if hasAnyClips {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSearch.toggle()
                            if !showSearch {
                                searchText = ""
                                searchFocused = false
                            }
                        }
                        if showSearch { searchFocused = true }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Button { showCalendar = true } label: {
                        Image(systemName: selectedDate == nil ? "calendar" : "calendar.badge.checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedDate == nil
                                             ? .white.opacity(0.8)
                                             : Color(red: 0.4, green: 0.72, blue: 1.0))
                    }
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if isSelecting {
                Button(selectedClipIDs.count == visibleClipIDs.count ? "None" : "All") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedClipIDs = selectedClipIDs.count == visibleClipIDs.count
                            ? []
                            : visibleClipIDs
                    }
                }
                .font(.system(size: 15, weight: .semibold))
            } else {
                HStack(spacing: 14) {
                    if hasAnyClips {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                groupByDrive.toggle()
                            }
                        } label: {
                            Image(systemName: groupByDrive ? "car.fill" : "list.bullet")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(groupByDrive
                                                 ? Color(red: 0.4, green: 0.72, blue: 1.0)
                                                 : .white.opacity(0.8))
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelecting = true
                            }
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    

    private var driveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("DRIVES")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.3)
                        .foregroundColor(.white.opacity(0.55))

                    Text("\(driveSessions.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }

                Text("Clips recorded close together, grouped by journey")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(driveSessions) { session in
                sessionCard(session)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionCard(_ session: DriveSession) -> some View {
        let isExpanded = expandedSessions.contains(session.id)

        return VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if isExpanded {
                        expandedSessions.remove(session.id)
                    } else {
                        expandedSessions.insert(session.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.4, green: 0.72, blue: 1.0))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.4, green: 0.72, blue: 1.0).opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.titleText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 5) {
                            Text("\(session.clips.count) clip\(session.clips.count == 1 ? "" : "s")")
                            Text("·")
                            Text(session.durationText)
                            Text("·")
                            Text(session.sizeText)

                            if session.savedCount > 0 {
                                Text("·")
                                HStack(spacing: 3) {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 8))
                                    Text("\(session.savedCount)")
                                }
                                .foregroundColor(Color(red: 1, green: 0.42, blue: 0.42))
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(session.clips) { clip in
                        clipRow(clip)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }



    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button {
                exportSelected()
            } label: {
                Label(
                    selectedClipIDs.isEmpty ? "Export" : "Export \(selectedClipIDs.count)",
                    systemImage: "square.and.arrow.up"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selectedClipIDs.isEmpty ? .white.opacity(0.3) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(selectedClipIDs.isEmpty
                                   ? Color.white.opacity(0.1)
                                   : Color.white)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedClipIDs.isEmpty)

            Button {
                deleteSelected()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(selectedClipIDs.isEmpty
                                     ? .white.opacity(0.25)
                                     : Color(red: 1, green: 0.42, blue: 0.42))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .disabled(selectedClipIDs.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Color.black.opacity(0.92)
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .transition(.move(edge: .bottom))
    }

    private func exportSelected() {
        let urls = selectedClips.map(\.url)
        guard !urls.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ShareSheetPresenter.present(items: urls)
    }

    private func deleteSelected() {
        let clips = selectedClips
        guard !clips.isEmpty else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        withAnimation(.easeOut(duration: 0.25)) {
            for clip in clips {
                ClipStorage.shared.deleteClip(clip.url)
                protectedClips.removeAll { $0.id == clip.id }
                loopClips.removeAll { $0.id == clip.id }
            }
            selectedClipIDs = []
            isSelecting = false
            refreshStorageFigures()
        }
    }



    private func clipRow(_ clip: DashcamClip) -> some View {
        HStack(spacing: 10) {
            if isSelecting {
                Image(systemName: selectedClipIDs.contains(clip.id)
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedClipIDs.contains(clip.id)
                                     ? Color(red: 0.4, green: 0.72, blue: 1.0)
                                     : .white.opacity(0.25))
                    .transition(.scale.combined(with: .opacity))
            }

            ClipRowView(clip: clip) {
                clipPendingDelete = clip
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelecting {
                withAnimation(.easeOut(duration: 0.15)) {
                    if selectedClipIDs.contains(clip.id) {
                        selectedClipIDs.remove(clip.id)
                    } else {
                        selectedClipIDs.insert(clip.id)
                    }
                }
            } else {
                playingClip = clip
            }
        }
 
        .onLongPressGesture {
            guard !isSelecting else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSelecting = true
                selectedClipIDs.insert(clip.id)
            }
        }
    }

    private func section(
        title: String,
        subtitle: String,
        count: Int,
        clips: [DashcamClip]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.3)
                        .foregroundColor(.white.opacity(0.55))

                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(clips) { clip in
                clipRow(clip)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }



    private var calendarSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: { newDate in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedDate = newDate
                            activeFilter = .all
                        }
                    ),
                    in: earliestClipDate...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color(red: 0.4, green: 0.72, blue: 1.0))
                .padding(.horizontal, 8)

                if let selectedDate {
                    let count = clipCount(on: selectedDate)
                    Text(count == 0
                         ? "No clips on this day"
                         : "\(count) clip\(count == 1 ? "" : "s") on this day")
                        .font(.system(size: 13))
                        .foregroundColor(count == 0 ? .orange.opacity(0.8) : .white.opacity(0.55))
                }

                Spacer()

                if selectedDate != nil {
                    Button {
                        withAnimation { selectedDate = nil }
                        showCalendar = false
                    } label: {
                        Text("Clear date filter")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top, 10)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showCalendar = false }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func selectedDateChip(_ date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"

        return HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.4, green: 0.72, blue: 1.0))

            Text(formatter.string(from: date))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { selectedDate = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.4, green: 0.72, blue: 1.0).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.4, green: 0.72, blue: 1.0).opacity(0.25), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func clipCount(on date: Date) -> Int {
        (protectedClips + loopClips).filter {
            Calendar.current.isDate($0.modifiedAt, inSameDayAs: date)
        }.count
    }

 

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))

            TextField("", text: $searchText, prompt:
                Text("Search by date or time").foregroundColor(.white.opacity(0.3))
            )
            .font(.system(size: 15))
            .foregroundColor(.white)
            .focused($searchFocused)
            .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClipFilter.allCases) { filter in
                    let isSelected = activeFilter == filter && selectedDate == nil
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activeFilter = filter
                            selectedDate = nil
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.09))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func apply(to clips: [DashcamClip]) -> [DashcamClip] {
        var result = clips

        if let selectedDate {
            result = result.filter {
                Calendar.current.isDate($0.modifiedAt, inSameDayAs: selectedDate)
            }
        } else {
            switch activeFilter {
            case .all: break
            case .saved: result = result.filter(\.isProtected)
            case .today: result = result.filter { Calendar.current.isDateInToday($0.modifiedAt) }
            case .week:
                let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
                result = result.filter { $0.modifiedAt >= cutoff }
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.dateText.lowercased().contains(query) }
        }

        return result
    }

    private var noMatchesState: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedDate != nil ? "calendar.badge.exclamationmark" : "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.white.opacity(0.25))

            Text("No clips match")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            Text(noMatchesHint)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var noMatchesHint: String {
        if selectedDate != nil {
            return "Nothing was recorded on this day, or those clips have since rotated out of the loop."
        }
        if activeFilter == .saved {
            return "You haven't saved any clips yet."
        }
        return "Try a different search or filter."
    }
    
    private var storageCard: some View {
        let capacity = ClipStorage.shared.maxLoopBytes
        let fraction = capacity > 0
            ? min(Double(loopUsedBytes) / Double(capacity), 1.0)
            : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STORAGE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.3)
                    .foregroundColor(.white.opacity(0.55))

                Spacer()

                if let remainingHours, remainingHours > 0 {
                    Text(remainingHours >= 1
                         ? String(format: "~%.1f hrs left", remainingHours)
                         : String(format: "~%.0f min left", remainingHours * 60))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(fraction > 0.9 ? Color.orange : Color.white.opacity(0.75))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)

            HStack(spacing: 14) {
                legendDot(
                    label: "Loop",
                    value: ByteCountFormatter.string(fromByteCount: loopUsedBytes, countStyle: .file),
                    color: .white.opacity(0.75)
                )
                legendDot(
                    label: "Saved",
                    value: ByteCountFormatter.string(fromByteCount: protectedUsedBytes, countStyle: .file),
                    color: Color(red: 1, green: 0.42, blue: 0.42)
                )
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private func legendDot(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white.opacity(0.5))
            Text("Loading clips…")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.white.opacity(0.25))

            Text("No clips yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Text("Recordings appear here once the dashcam has been running for a few minutes. Tap Save Clip any time to keep the moment you're in.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.top, 30)
    }



    private func reload() async {
        let (protected, loop) = DashcamClip.load()

        protectedClips = await resolve(protected)
        loopClips = await resolve(loop.filter { $0.url != activeSegmentURL })

        
        if !didAutoExpand, let newest = DriveSession.group(loopClips).first {
            expandedSessions.insert(newest.id)
            didAutoExpand = true
        }

        refreshStorageFigures()
        isLoading = false
    }

    private func resolve(_ clips: [DashcamClip]) async -> [DashcamClip] {
        var result: [DashcamClip] = []
        for var clip in clips {
            if let seconds = await ClipThumbnailGenerator.duration(for: clip.url) {
                clip.durationSeconds = seconds
                result.append(clip)
            } else {
                ClipStorage.shared.deleteClip(clip.url)
            }
        }
        return result
    }

    private func refreshStorageFigures() {
        loopUsedBytes = ClipStorage.shared.loopBytesUsed()
        protectedUsedBytes = ClipStorage.shared.protectedBytesUsed()
        remainingHours = ClipStorage.shared.estimatedRemainingHours()
    }

    private func deleteSingle(_ clip: DashcamClip) {
        ClipStorage.shared.deleteClip(clip.url)
        withAnimation(.easeOut(duration: 0.25)) {
            protectedClips.removeAll { $0.id == clip.id }
            loopClips.removeAll { $0.id == clip.id }
            refreshStorageFigures()
        }
    }
}


enum ShareSheetPresenter {
    static func present(items: [URL]) {
        guard !items.isEmpty else { return }
        
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController
        else { return }
        
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 60,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        presenter.present(controller, animated: true)
    }
}

