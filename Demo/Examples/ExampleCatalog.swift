//
//  ExampleCatalog.swift
//  Demo
//

import Foundation

/// Every example the demo app ships, in the order the browser and the published
/// documentation present them.
///
/// Adding an example means adding one file under `Demo/Examples/<Category>/` and one
/// entry here. `Demo/` is a synchronized folder in the Xcode project, so no project
/// edit is needed.
enum ExampleCatalog {
    static let categories: [ExampleCategory] = [
        explore,
        gettingStarted,
        styling,
        features,
        animation,
        readouts,
        customData
    ]

    /// The full-featured weather app in the demo, kept at the top on its own: it is
    /// the fastest way to see every layer, and the only entry that is not scoped to
    /// one API.
    static let explore = ExampleCategory(
        title: "Explore",
        examples: [
            Example(
                slug: "weather-layer-explorer",
                title: "Weather layer explorer",
                summary: "Browse every weather layer, with timeline playback, legends, and data inspection.",
                isDocumented: false
            ) {
                LayerBrowserExample()
            }
        ]
    )

    static let gettingStarted = ExampleCategory(
        title: "Getting Started",
        examples: [
            Example(
                slug: "display-a-weather-map",
                title: "Display a weather map",
                summary: "Wire up a map, a controller and two weather layers, with no demo scaffolding."
            ) {
                DisplayAWeatherMapExample()
            },
            Example(
                slug: "uikit-integration",
                title: "UIKit integration",
                summary: "Drive the same map controller from a UIViewController instead of SwiftUI."
            ) {
                UIKitIntegrationExample()
            }
        ]
    )

    /// Repainting the continuous fields — sample and particle layers — that the
    /// built-in weather catalog draws: color scales, draw ranges, particle motion.
    static let styling = ExampleCategory(
        title: "Styling Weather Layers",
        examples: [
            Example(
                slug: "custom-radar-colors",
                title: "Custom radar colors",
                summary: "Swap between per-precipitation-type radar masks and generic single-value palettes."
            ) {
                CustomRadarColorsExample()
            },
            Example(
                slug: "custom-temperature-colors",
                title: "Custom temperature colors",
                summary: "Replace a sample layer's color scale, as a gradient or in fixed bands."
            ) {
                CustomTemperatureColorsExample()
            },
            Example(
                slug: "adjust-draw-range",
                title: "Adjust the draw range",
                summary: "Clip a layer to part of its data range and change it live."
            ) {
                AdjustDrawRangeExample()
            },
            Example(
                slug: "frost-freeze-layer",
                title: "Frost and freeze map",
                summary: "Clip and band the temperatures layer into agricultural frost categories."
            ) {
                FrostFreezeLayerExample()
            },
            Example(
                slug: "wind-speed-categories-layer",
                title: "Wind speed categories",
                summary: "Show only notable wind, painted as named categories rather than a gradient."
            ) {
                WindSpeedCategoriesExample()
            },
            Example(
                slug: "custom-wind-particles",
                title: "Custom wind particles",
                summary: "Tune particle density, speed, trails and color on the wind field."
            ) {
                CustomWindParticlesExample()
            }
        ]
    )

    /// Vector layers, where both the styling and the choice of what to draw are
    /// expressions evaluated against each feature's own properties.
    static let features = ExampleCategory(
        title: "Features & Filtering",
        examples: [
            Example(
                slug: "custom-alert-styles",
                title: "Custom alert styles",
                summary: "Color alert polygons by severity instead of by alert type."
            ) {
                CustomAlertStylesExample()
            },
            Example(
                slug: "custom-lightning-styles",
                title: "Custom lightning styles",
                summary: "Fade lightning strikes out as they age, using a step expression."
            ) {
                CustomLightningStylesExample()
            },
            Example(
                slug: "filter-alerts",
                title: "Filter weather alerts",
                summary: "Draw a subset of a layer's features with a filter expression."
            ) {
                FilterAlertsExample()
            }
        ]
    )

    static let animation = ExampleCategory(
        title: "Animation",
        examples: [
            Example(
                slug: "timeline-controls",
                title: "Timeline controls",
                summary: "Play, pause, resume and scrub the timeline, keeping your own UI in step."
            ) {
                TimelineControlsExample()
            },
            Example(
                slug: "change-timeline-range",
                title: "Change the timeline range",
                summary: "Move the animation window between history and forecast at runtime."
            ) {
                ChangeTimelineRangeExample()
            },
            Example(
                slug: "preload-animation-data",
                title: "Preload animation data",
                summary: "Fetch every frame up front so the first loop plays without stalling."
            ) {
                PreloadAnimationDataExample()
            }
        ]
    )

    /// Reading values back off the map: the legend and inspector controls, the units
    /// those values are displayed in, and layers that label points with sampled data.
    static let readouts = ExampleCategory(
        title: "Legends, Units & Readouts",
        examples: [
            Example(
                slug: "legend-and-inspector",
                title: "Legend and data inspector",
                summary: "Add the SDK's legend and tap-to-inspect controls, and query values directly."
            ) {
                LegendAndInspectorExample()
            },
            Example(
                slug: "custom-heat-index-legend",
                title: "Custom legend labels",
                summary: "Relabel a layer's legend with categories instead of values."
            ) {
                CustomHeatIndexLegendExample()
            },
            Example(
                slug: "change-map-units",
                title: "Change map units",
                summary: "Change one quantity's units and watch every layer, legend and readout follow."
            ) {
                ChangeMapUnitsExample()
            },
            Example(
                slug: "query-layer-api-geojson",
                title: "Values at API places",
                summary: "Label the largest US cities with temperatures sampled from a weather layer."
            ) {
                QueryLayerAPIGeoJSONExample()
            },
            Example(
                slug: "query-layer-static-geojson",
                title: "Values at your own points",
                summary: "Sample wind speeds at points you supply, labelled with their place names."
            ) {
                QueryLayerStaticGeoJSONExample()
            }
        ]
    )

    /// Sources MapsGL knows nothing about: your own tiles, geometry and imagery,
    /// added alongside the weather layers.
    static let customData = ExampleCategory(
        title: "Your Own Data",
        examples: [
            Example(
                slug: "custom-raster-layer",
                title: "Custom raster layer",
                summary: "Draw your own {z}/{x}/{y} image tiles with an ImageSourceDescriptor."
            ) {
                CustomRasterLayerExample()
            },
            Example(
                slug: "custom-vector-layer",
                title: "Custom vector layer",
                summary: "Render a vector tile source, colored from each feature's own properties."
            ) {
                CustomVectorLayerExample()
            },
            Example(
                slug: "custom-geojson-layer",
                title: "Custom GeoJSON layer",
                summary: "Draw your own GeoJSON geometry, filled and outlined from one source."
            ) {
                CustomGeoJSONLayerExample()
            },
            Example(
                slug: "layer-masking",
                title: "Layer masking",
                summary: "Clip a raster layer to land or to water with a mask configuration."
            ) {
                LayerMaskingExample()
            }
        ]
    )

    /// Categories with only the examples matching `term`, dropping any that empty out.
    static func filtered(by term: String) -> [ExampleCategory] {
        categories
            .map { $0.filtered(by: term) }
            .filter { !$0.examples.isEmpty }
    }
}
