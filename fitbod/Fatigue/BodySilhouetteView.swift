//
//  BodySilhouetteView.swift
//  fitbod
//
//  Phase 5 VOL-05 — body silhouette heatmap rendered as ZStack of
//  per-region Path overlays per RESEARCH §8.2.
//
//  Layout: `.aspectRatio(0.4, contentMode: .fit)` on the
//  GeometryReader — the silhouette is tall + narrow per UI-SPEC §
//  Spacing Scale. Inside, each muscle slug from MuscleRegionPaths
//  is drawn as a `.fill(zoneColor(zone))` path with
//  `.contentShape(scaledPath)` hit-testing per RESEARCH §8.5.
//
//  Small regions (neck / forearms / abductors / adductors) are
//  wrapped in a min 44x44 `.frame` to satisfy the 44pt HIG hit-
//  target contract while the visual fidelity of the actual path
//  stays unchanged.
//
//  Asset Catalog zone colors only (NEVER `Color.red` / `.green`
//  literals).
//

import SwiftUI

/// Toggles between front-view and back-view paths.
public enum BodySide: String, Sendable, Equatable, Hashable, CaseIterable {
    case front, back
}

public struct BodySilhouetteView: View {
    public let side: BodySide
    public let zoneByMuscleSlug: [String: VolumeZone]
    public let muscleDisplayNames: [String: String]
    public let onTap: (String) -> Void

    public init(
        side: BodySide,
        zoneByMuscleSlug: [String: VolumeZone],
        muscleDisplayNames: [String: String],
        onTap: @escaping (String) -> Void
    ) {
        self.side = side
        self.zoneByMuscleSlug = zoneByMuscleSlug
        self.muscleDisplayNames = muscleDisplayNames
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { geo in
            let paths: [String: Path] = side == .front
                ? MuscleRegionPaths.front
                : MuscleRegionPaths.back

            ZStack {
                ForEach(Array(paths.keys.sorted()), id: \.self) { slug in
                    let normalizedPath = paths[slug]!
                    let scaledPath = normalizedPath.applying(
                        CGAffineTransform(scaleX: geo.size.width, y: geo.size.height)
                    )
                    let zone = zoneByMuscleSlug[slug] ?? .belowMEV

                    scaledPath
                        .fill(zoneColor(zone))
                        .contentShape(scaledPath)
                        .frame(
                            minWidth: needsHitPadding(slug: slug) ? 44 : 0,
                            minHeight: needsHitPadding(slug: slug) ? 44 : 0
                        )
                        .onTapGesture { onTap(slug) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(muscleDisplayNames[slug] ?? slug.capitalized): \(zone.verb).")
                        .accessibilityHint("Tap to see details.")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .aspectRatio(0.4, contentMode: .fit)
    }

    /// Small anatomical regions whose actual `Path` would render below
    /// the 44pt HIG hit target. Per UI-SPEC §Interaction & Motion the
    /// `.frame` enlarges the tap area while the visual `.contentShape`
    /// stays on the actual path.
    private func needsHitPadding(slug: String) -> Bool {
        ["neck", "forearms", "abductors", "adductors"].contains(slug)
    }

    private func zoneColor(_ z: VolumeZone) -> Color {
        switch z {
        case .belowMEV:   return Color("VolumeBelowMEVGray")
        case .productive: return Color("VolumeProductiveGreen")
        case .nearMRV:    return Color("VolumeNearMRVAmber")
        case .overMRV:    return Color("VolumeOverMRVRed")
        }
    }
}
