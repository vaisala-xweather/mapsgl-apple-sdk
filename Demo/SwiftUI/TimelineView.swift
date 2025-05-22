//
//  TimelineView.swift
//  Demo
//
//  Created by Nicholas Shipes on 4/30/25.
//

import SwiftUI

struct TimelineView: View {
    @Binding var timelinePosition: Double
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var currentDate: Date
    @Binding var selectedSpeed: Double
    @Binding var isPlaying: Bool
    @Binding var isLoading: Bool
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            Slider(value: $timelinePosition, in: 0...1)
                .padding(.horizontal)

            HStack {
                // time & date labels
                VStack(alignment: .leading, spacing: 2) {
                    Text($currentDate.wrappedValue, formatter: Self.timeFormatter)
                        .font(.title2)
                    Text($currentDate.wrappedValue, formatter: Self.dateFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // activity spinner
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.leading, 8)
                }

                // playback + settings
                HStack(spacing: 12) {
//                    CircularIconButton(systemName: "backward.fill") {
//                        // rewind
//                    }
                    CircularIconButton(
                        systemName: isPlaying ? "pause.fill" : "play.fill",
                        insets: EdgeInsets(top: 0, leading: isPlaying ? 0 : 4, bottom: 0, trailing: 0)
                    ) {
                        isPlaying.toggle()
                    }
//                    CircularIconButton(systemName: "forward.fill") {
//                        // fast-forward
//                    }
                    CircularIconButton(imageName: "MapsGL.Settings") {
                        showSettings = true
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .popover(isPresented: $showSettings, attachmentAnchor: .point(.center), arrowEdge: .bottom) {
            SettingsView(
                startDate: $startDate,
                endDate: $endDate,
                selectedSpeed: $selectedSpeed
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: Date Formatters

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E, MMM d"
        return f
    }()
}

struct SettingsView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedSpeed: Double
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // — Header —
                HStack {
                    Text("Timeline")
                        .font(.titleFont)
                        .lineSpacing(20)
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // — Date Range —
                Text("Date Range")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal)
                
                // Start row
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Start")
                        .font(.body).fontWeight(.semibold)
                    Spacer()
                    Text(startDate, formatter: dateTimeFormatter)
                }
                .padding(.horizontal)
                
                // Start row buttons
                HStack(spacing: 8) {
                    OffsetButton(label: "-1 day") { adjust(&startDate, by: .day, -1) }
                        .frame(maxWidth: .infinity)
                    OffsetButton(label: "-1 hour") { adjust(&startDate, by: .hour, -1) }
                        .frame(maxWidth: .infinity)
                    OffsetButton(label: "+1 hour") { adjust(&startDate, by: .hour, 1) }
                        .frame(maxWidth: .infinity)
                    OffsetButton(label: "+1 day") { adjust(&startDate, by: .day, 1) }
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                // End row
                HStack {
                    Image(systemName: "arrow.right")
                    Text("End")
                        .font(.body).fontWeight(.semibold)
                    Spacer()
                    Text(endDate, formatter: dateTimeFormatter)
                }
                .padding(.horizontal)
                
                // End row buttons
                HStack(spacing: 8) {
                    OffsetButton(label: "-1 day") { adjust(&endDate, by: .day, -1) }
                        .frame(maxWidth: .infinity)
                    OffsetButton(label: "-1 hour") { adjust(&endDate, by: .hour, -1) }
                        .frame(maxWidth: .infinity)
                    OffsetButton(label: "+1 hour") { adjust(&endDate, by: .hour, 1) }
                        .frame(maxWidth: .infinity)
                    OffsetButton(label: "+1 day") { adjust(&endDate, by: .day, 1) }
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                Text("Shift the start/end times by adding or removing hour or day intervals.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
                
                // — Animation Speed —
                Text("Animation")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "clock")
                    Text("Speed")
                        .font(.body).fontWeight(.semibold)
                }
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    ForEach([0.25, 0.5, 1.0, 2.0], id: \.self) { speed in
                        let title = speed == 1.0 ? "1x" : String(format: "%.2gx", speed)
                        OffsetButton(label: title, isSelected: selectedSpeed == speed) {
                            selectedSpeed = speed
                        }
                        .frame(minWidth: 32, minHeight: 32)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
        }
    }

    // apply a calendar offset
    private func adjust(_ date: inout Date, by component: Calendar.Component, _ value: Int) {
        date = Calendar.current.date(byAdding: component, value: value, to: date) ?? date
    }

    // date + time formatter
    private var dateTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy h:mma"
        return f
    }
}

struct OffsetButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    init(label: String, isSelected: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.primary : Color(.systemGray5))
        .foregroundColor(isSelected ? Color(.white) : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct Timeline_Previews: PreviewProvider {
    @State static var pos = 0.3
    @State static var playing = false
    @State static var loading = true
    
    static var previews: some View {
        TimelineView(
            timelinePosition: $pos,
            startDate: .constant(Calendar.current.date(byAdding: .hour, value: -1, to: .now)!),
            endDate: .constant(Date()),
            currentDate: .constant(Date()),
            selectedSpeed: .constant(1.0),
            isPlaying: $playing,
            isLoading: $loading
        )
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
