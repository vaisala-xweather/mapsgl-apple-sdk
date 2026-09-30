//
//  FilterAlertsExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Showing only some of a layer's features, using its filter expression.
///
/// A vector layer's `filter` is evaluated per feature against its properties, so the
/// data is fetched once and the map draws the subset that passes. Alerts carry a
/// `VTEC` code identifying the alert type, which makes a membership test the natural
/// filter — the built-in "short fuse" alerts layer is the same idea with a fixed set.
///
/// Filtering beats adding and removing layers here: the tiles never reload.
struct FilterAlertsExample: View {
    /// The same groupings and VTEC codes the JavaScript `filter-alerts` example uses.
    /// Codes are listed at xweather.com/docs/maps/reference/alert-types.
    private enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case severe = "Severe"
        case fire = "Fire"
        case flood = "Flood"
        case heat = "Heat"
        case wind = "Wind"
        case tropical = "Tropical"
        case winter = "Winter"
        case freeze = "Freeze"

        var id: Self { self }

        /// VTEC phenomenon/significance codes for each grouping, or `nil` for no filter.
        var vtecCodes: [String]? {
            switch self {
            case .all:
                nil
            case .severe:
                ["SV.W", "TO.W", "FF.W", "MA.W", "FF.A", "MA.A", "TO.A", "SV.A",
                 "AW.TS.MN", "AW.TS.MD", "AW.TS.SV", "AW.TS.EX"]
            case .fire:
                ["FW.A", "FRW", "RFD", "FW.W",
                 "AW.FR.MN", "AW.FR.MD", "AW.FR.SV", "AW.FR.EX"]
            case .flood:
                ["FL.Y", "FL.A", "FL.W", "FL.S", "FA.W", "FA.A", "FF.A", "FF.W", "RA.W",
                 "AW.RA.MN", "AW.RA.MD", "AW.RA.SV", "AW.RA.EX",
                 "AW.FL.MN", "AW.FL.MD", "AW.FL.SV", "AW.FL.EX",
                 "AW.RF.MN", "AW.RF.MD", "AW.RF.SV", "AW.RF.EX"]
            case .heat:
                ["EH.A", "EH.W", "HT.Y", "HT.W",
                 "AW.HT.MN", "AW.HT.MD", "AW.HT.SV", "AW.HT.EX"]
            case .wind:
                ["BW.Y", "EW.W", "HW.W", "HW.A", "HF.W", "HF.A", "LW.Y", "SI.Y", "WI.Y", "WI.W",
                 "AW.WI.MN", "AW.WI.MD", "AW.WI.SV", "AW.WI.EX"]
            case .tropical:
                ["TC.S", "TR.S", "TR.W", "TR.A", "HF.W", "HF.A", "HU.S", "HU.W", "HU.A"]
            case .winter:
                ["AR.W", "AVW", "AVA", "AV.Y", "BZ.W", "BS.Y", "EC.W", "EC.A", "ZL.Y", "ZF.Y",
                 "ZR.W", "ZY.Y", "UP.W", "UP.A", "IS.W", "LE.W", "LW.Y", "SQ.W", "SQ.A", "SB.Y",
                 "SN.W", "WC.Y", "WC.W", "WC.A", "WS.W", "WS.A", "LE.A", "BZ.A", "WW.Y", "LE.Y",
                 "ZR.Y",
                 "AW.SI.MN", "AW.SI.MD", "AW.SI.SV", "AW.SI.EX",
                 "AW.AV.MN", "AW.AV.MD", "AW.AV.SV", "AW.AV.EX",
                 "AW.LT.MN", "AW.LT.MD", "AW.LT.SV", "AW.LT.EX"]
            case .freeze:
                ["FE.W", "FZ.W", "FZ.A", "HZ.W", "HZ.A",
                 "AW.LT.MN", "AW.LT.MD", "AW.LT.SV", "AW.LT.EX"]
            }
        }
    }

    @State private var category: Category = .all

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -93), zoom: 3) { mapController, subscriptions in
            addAlerts(to: mapController)
        } overlay: { mapController in
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()

                // Names what actually passed the filter, so an empty map is
                // distinguishable from a broken one.
                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame()

                VStack(alignment: .leading, spacing: 14) {
                ExampleControlGroup(title: "Alert type") {
                    Picker("Alert type", selection: $category) {
                        ForEach(Category.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: category) { _ in
                        guard let mapController else { return }
                        mapController.removeWeatherLayer(for: .alerts)
                        addAlerts(to: mapController)
                    }
                }
                }
                .exampleControlSurface()
            }
        }
    }

    private func addAlerts(to mapController: DemoMapController) {
        var config = WeatherService.Alerts(service: mapController.service)

        if let codes = category.vtecCodes {
            config.layer.filter = Expression.contains(Expression.get("VTEC"), in: codes)
        }

        do {
            let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                for: mapController,
                layerCode: .alerts
            )
            try mapController.addWeatherLayer(config: config, beforeId: beforeId)
        } catch {
            print("Failed to add the alerts layer: \(error)")
        }
    }
}

#Preview {
    FilterAlertsExample()
}
