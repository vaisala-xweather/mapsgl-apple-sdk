//
//  Example.swift
//  Demo
//

import SwiftUI

/// One entry in the demo app's example browser.
///
/// `slug` is the join key to the published documentation: an example whose slug is
/// `"custom-radar-colors"` is documented at
/// `xweather.com/docs/mapsgl-apple-sdk/examples/custom-radar-colors`, and its
/// source file is the code sample on that page.
struct Example: Identifiable {
    /// Stable, lowercase-hyphenated identifier. Matches the documentation page's slug.
    let slug: String

    /// Short title shown in the browser and used as the pushed screen's navigation title.
    let title: String

    /// One sentence on what the example demonstrates.
    let summary: String

    /// Whether the example is published to the documentation site.
    ///
    /// An example that only makes sense as a running app — one that is a tour of
    /// the demo rather than a lesson in one API — stays here and out of the docs.
    /// `scripts/export-example-docs` skips it.
    let isDocumented: Bool

    /// Builds the example's screen. Called each time the row is opened.
    let destination: () -> AnyView

    var id: String { slug }

    init<Content: View>(
        slug: String,
        title: String,
        summary: String,
        isDocumented: Bool = true,
        @ViewBuilder destination: @escaping () -> Content
    ) {
        self.slug = slug
        self.title = title
        self.summary = summary
        self.isDocumented = isDocumented
        self.destination = { AnyView(destination()) }
    }

    /// Whether `term` matches this example's title, summary, or slug.
    func matches(_ term: String) -> Bool {
        guard !term.isEmpty else {
            return true
        }

        return title.localizedCaseInsensitiveContains(term)
            || summary.localizedCaseInsensitiveContains(term)
            || slug.localizedCaseInsensitiveContains(term)
    }
}

/// A named group of examples, rendered as one section of the browser.
struct ExampleCategory: Identifiable {
    let title: String
    let examples: [Example]

    var id: String { title }

    /// This category with only the examples matching `term`.
    func filtered(by term: String) -> ExampleCategory {
        ExampleCategory(title: title, examples: examples.filter { $0.matches(term) })
    }
}
