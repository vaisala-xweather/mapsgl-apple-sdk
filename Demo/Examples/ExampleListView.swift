//
//  ExampleListView.swift
//  Demo
//

import SwiftUI

/// The demo app's root: a searchable, grouped list of every example.
///
/// Laid out as an index rather than a set of cards — an overline naming each
/// category, a rule under it, and one line per example — which is the design
/// system's structure for a technical page.
struct ExampleListView: View {
    @State private var searchText = ""

    private var categories: [ExampleCategory] {
        ExampleCatalog.filtered(by: searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    // The category label is the section's first row rather than its
                    // header: a plain list pins a header, and a band of chrome
                    // sliding over the rows is not how an index reads. Everything
                    // here scrolls together.
                    Section {
                        CategoryHeader(title: category.title)

                        ForEach(category.examples) { example in
                            NavigationLink {
                                ExampleContainer {
                                    example.destination()
                                }
                                .navigationTitle(example.title)
                            } label: {
                                ExampleRow(example: example)
                            }
                            .listRowBackground(XWColor.backgroundPrimary)
                            .listRowSeparatorTint(XWColor.borderSubtle)
                        }
                    }
                }

                if categories.isEmpty {
                    Text("No examples match \u{201C}\(searchText)\u{201D}.")
                        .xwSmall()
                        .foregroundStyle(XWColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, XWSpace.x8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(XWColor.backgroundPrimary)
            .navigationTitle("MapsGL Examples")
            .searchable(text: $searchText, prompt: "Search examples")
        }
    }
}

/// A category's overline and the rule that opens its section.
private struct CategoryHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: XWSpace.x2) {
            Text(title)
                .xwOverline()
            XWDivider(color: XWColor.border)
        }
        .padding(.horizontal, XWSpace.x4)
        .padding(.top, XWSpace.x6)
        .padding(.bottom, XWSpace.x1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets())
        .listRowBackground(XWColor.backgroundPrimary)
        .listRowSeparator(.hidden)
    }
}

private struct ExampleRow: View {
    let example: Example

    var body: some View {
        VStack(alignment: .leading, spacing: XWSpace.x1) {
            Text(example.title)
                .xwBody()
                .foregroundStyle(XWColor.textPrimary)
            Text(example.summary)
                .xwSmall()
                .foregroundStyle(XWColor.textSecondary)
        }
        .padding(.vertical, XWSpace.x2)
    }
}

#Preview {
    ExampleListView()
}
