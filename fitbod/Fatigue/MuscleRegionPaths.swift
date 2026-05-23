//
//  MuscleRegionPaths.swift
//  fitbod
//
//  Per-muscle silhouette `Path` registry per RESEARCH §8.2. Paths are
//  normalized to a 0...1 unit square; callers render inside a
//  `GeometryReader` to scale to the device.
//
//  Wave 3 refinement (Phase 5 plan 05) — replaces plan 01's
//  axis-aligned `Path(CGRect(...))` stubs with rounded-corner +
//  contour-curve approximations of each muscle region. Coordinates
//  derive from the free-exercise-db reference body figure (BSD-2;
//  positions inferred not traced). Public surface unchanged from
//  plan 01: `static let front: [String: Path]` + `static let back:
//  [String: Path]`.
//
//  Coverage: combined `front ∪ back` covers all 17 free-exercise-db
//  slugs. Plan 01's `MuscleRegionPathsTests.combinedRegistry-
//  CoversAllSeventeenMuscleSlugs` continues to pin the contract
//  regardless of geometry refinement.
//
//  Hit-testing: every Path is closed (`.closeSubpath`) so SwiftUI's
//  `.contentShape(path)` rejects taps outside the visible region.
//
//  No SwiftData coupling. Implicitly Sendable via SwiftUI.Path
//  (value type).
//

import SwiftUI

public enum MuscleRegionPaths {

    /// Front-view paths keyed by muscle slug.
    public static let front: [String: Path] = [
        "chest":      makeChestFront(),
        "shoulders":  makeShouldersFront(),
        "biceps":     makeBicepsFront(),
        "forearms":   makeForearmsFront(),
        "abdominals": makeAbdominalsFront(),
        "quadriceps": makeQuadricepsFront(),
        "calves":     makeCalvesFront(),
        "neck":       makeNeckFront(),
        "abductors":  makeAbductorsFront(),
        "adductors":  makeAdductorsFront(),
    ]

    /// Back-view paths keyed by muscle slug.
    public static let back: [String: Path] = [
        "traps":       makeTrapsBack(),
        "lats":        makeLatsBack(),
        "middle back": makeMiddleBackBack(),
        "lower back":  makeLowerBackBack(),
        "shoulders":   makeShouldersBack(),
        "triceps":     makeTricepsBack(),
        "glutes":      makeGlutesBack(),
        "hamstrings":  makeHamstringsBack(),
        "calves":      makeCalvesBack(),
        "forearms":    makeForearmsBack(),
    ]

    // MARK: - Front-view builders

    /// Rounded-rectangle helper — bezier curves at the corners
    /// approximate the soft contour of muscle bellies vs the
    /// axis-aligned stubs from plan 01.
    private static func roundedRectPath(
        x: CGFloat, y: CGFloat,
        width w: CGFloat, height h: CGFloat,
        cornerRadius cr: CGFloat = 0.02
    ) -> Path {
        Path { p in
            let cornerRadius = min(cr, min(w, h) / 2)
            p.move(to: CGPoint(x: x + cornerRadius, y: y))
            p.addLine(to: CGPoint(x: x + w - cornerRadius, y: y))
            p.addQuadCurve(
                to: CGPoint(x: x + w, y: y + cornerRadius),
                control: CGPoint(x: x + w, y: y)
            )
            p.addLine(to: CGPoint(x: x + w, y: y + h - cornerRadius))
            p.addQuadCurve(
                to: CGPoint(x: x + w - cornerRadius, y: y + h),
                control: CGPoint(x: x + w, y: y + h)
            )
            p.addLine(to: CGPoint(x: x + cornerRadius, y: y + h))
            p.addQuadCurve(
                to: CGPoint(x: x, y: y + h - cornerRadius),
                control: CGPoint(x: x, y: y + h)
            )
            p.addLine(to: CGPoint(x: x, y: y + cornerRadius))
            p.addQuadCurve(
                to: CGPoint(x: x + cornerRadius, y: y),
                control: CGPoint(x: x, y: y)
            )
            p.closeSubpath()
        }
    }

    /// Chest — upper torso, contoured at the sternum dip.
    private static func makeChestFront() -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0.30, y: 0.20))
            p.addCurve(
                to: CGPoint(x: 0.50, y: 0.22),
                control1: CGPoint(x: 0.38, y: 0.18),
                control2: CGPoint(x: 0.46, y: 0.21)
            )
            p.addCurve(
                to: CGPoint(x: 0.70, y: 0.20),
                control1: CGPoint(x: 0.54, y: 0.21),
                control2: CGPoint(x: 0.62, y: 0.18)
            )
            p.addQuadCurve(
                to: CGPoint(x: 0.68, y: 0.32),
                control: CGPoint(x: 0.72, y: 0.26)
            )
            p.addCurve(
                to: CGPoint(x: 0.32, y: 0.32),
                control1: CGPoint(x: 0.56, y: 0.34),
                control2: CGPoint(x: 0.44, y: 0.34)
            )
            p.addQuadCurve(
                to: CGPoint(x: 0.30, y: 0.20),
                control: CGPoint(x: 0.28, y: 0.26)
            )
            p.closeSubpath()
        }
    }

    /// Shoulders — front delts, two symmetric lobes flanking the chest.
    private static func makeShouldersFront() -> Path {
        Path { p in
            // Left front delt
            p.addEllipse(in: CGRect(x: 0.14, y: 0.18, width: 0.16, height: 0.10))
            // Right front delt
            p.addEllipse(in: CGRect(x: 0.70, y: 0.18, width: 0.16, height: 0.10))
        }
    }

    /// Biceps — upper arms, both sides. Tall ellipse along arm axis.
    private static func makeBicepsFront() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.08, y: 0.26, width: 0.14, height: 0.14))
            p.addEllipse(in: CGRect(x: 0.78, y: 0.26, width: 0.14, height: 0.14))
        }
    }

    /// Forearms — lower arms, both sides.
    private static func makeForearmsFront() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.06, y: 0.40, width: 0.13, height: 0.13))
            p.addEllipse(in: CGRect(x: 0.81, y: 0.40, width: 0.13, height: 0.13))
        }
    }

    /// Abdominals — mid-torso, narrower than chest, lozenge-shaped.
    private static func makeAbdominalsFront() -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0.42, y: 0.34))
            p.addCurve(
                to: CGPoint(x: 0.58, y: 0.34),
                control1: CGPoint(x: 0.46, y: 0.33),
                control2: CGPoint(x: 0.54, y: 0.33)
            )
            p.addCurve(
                to: CGPoint(x: 0.56, y: 0.50),
                control1: CGPoint(x: 0.60, y: 0.40),
                control2: CGPoint(x: 0.58, y: 0.46)
            )
            p.addCurve(
                to: CGPoint(x: 0.44, y: 0.50),
                control1: CGPoint(x: 0.50, y: 0.52),
                control2: CGPoint(x: 0.50, y: 0.52)
            )
            p.addCurve(
                to: CGPoint(x: 0.42, y: 0.34),
                control1: CGPoint(x: 0.42, y: 0.46),
                control2: CGPoint(x: 0.40, y: 0.40)
            )
            p.closeSubpath()
        }
    }

    /// Quadriceps — upper legs, two parallel cylinders.
    private static func makeQuadricepsFront() -> Path {
        Path { p in
            // Left thigh
            p.addRoundedRect(
                in: CGRect(x: 0.30, y: 0.55, width: 0.16, height: 0.20),
                cornerSize: CGSize(width: 0.04, height: 0.04)
            )
            // Right thigh
            p.addRoundedRect(
                in: CGRect(x: 0.54, y: 0.55, width: 0.16, height: 0.20),
                cornerSize: CGSize(width: 0.04, height: 0.04)
            )
        }
    }

    /// Calves — front-view shins (slimmer than back view).
    private static func makeCalvesFront() -> Path {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: 0.32, y: 0.78, width: 0.13, height: 0.13),
                cornerSize: CGSize(width: 0.03, height: 0.03)
            )
            p.addRoundedRect(
                in: CGRect(x: 0.55, y: 0.78, width: 0.13, height: 0.13),
                cornerSize: CGSize(width: 0.03, height: 0.03)
            )
        }
    }

    /// Neck — small region at the top.
    private static func makeNeckFront() -> Path {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: 0.42, y: 0.08, width: 0.16, height: 0.07),
                cornerSize: CGSize(width: 0.03, height: 0.03)
            )
        }
    }

    /// Abductors — outer hips, small slivers either side.
    private static func makeAbductorsFront() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.24, y: 0.50, width: 0.08, height: 0.08))
            p.addEllipse(in: CGRect(x: 0.68, y: 0.50, width: 0.08, height: 0.08))
        }
    }

    /// Adductors — inner thigh, central wedge.
    private static func makeAdductorsFront() -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0.46, y: 0.55))
            p.addLine(to: CGPoint(x: 0.54, y: 0.55))
            p.addCurve(
                to: CGPoint(x: 0.52, y: 0.66),
                control1: CGPoint(x: 0.55, y: 0.60),
                control2: CGPoint(x: 0.53, y: 0.64)
            )
            p.addLine(to: CGPoint(x: 0.48, y: 0.66))
            p.addCurve(
                to: CGPoint(x: 0.46, y: 0.55),
                control1: CGPoint(x: 0.47, y: 0.64),
                control2: CGPoint(x: 0.45, y: 0.60)
            )
            p.closeSubpath()
        }
    }

    // MARK: - Back-view builders

    /// Traps — diamond shape from neck base to mid-back.
    private static func makeTrapsBack() -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0.50, y: 0.10))
            p.addLine(to: CGPoint(x: 0.66, y: 0.16))
            p.addLine(to: CGPoint(x: 0.50, y: 0.24))
            p.addLine(to: CGPoint(x: 0.34, y: 0.16))
            p.closeSubpath()
        }
    }

    /// Lats — V-shape flanking the spine, widest at upper back.
    private static func makeLatsBack() -> Path {
        Path { p in
            // Left lat
            p.move(to: CGPoint(x: 0.30, y: 0.24))
            p.addCurve(
                to: CGPoint(x: 0.42, y: 0.42),
                control1: CGPoint(x: 0.20, y: 0.28),
                control2: CGPoint(x: 0.32, y: 0.38)
            )
            p.addLine(to: CGPoint(x: 0.48, y: 0.42))
            p.addLine(to: CGPoint(x: 0.48, y: 0.24))
            p.closeSubpath()
            // Right lat
            p.move(to: CGPoint(x: 0.70, y: 0.24))
            p.addCurve(
                to: CGPoint(x: 0.58, y: 0.42),
                control1: CGPoint(x: 0.80, y: 0.28),
                control2: CGPoint(x: 0.68, y: 0.38)
            )
            p.addLine(to: CGPoint(x: 0.52, y: 0.42))
            p.addLine(to: CGPoint(x: 0.52, y: 0.24))
            p.closeSubpath()
        }
    }

    /// Middle back — central spine column between the lats.
    private static func makeMiddleBackBack() -> Path {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: 0.48, y: 0.22, width: 0.04, height: 0.18),
                cornerSize: CGSize(width: 0.01, height: 0.01)
            )
        }
    }

    /// Lower back — small region below mid-back.
    private static func makeLowerBackBack() -> Path {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: 0.42, y: 0.42, width: 0.16, height: 0.08),
                cornerSize: CGSize(width: 0.02, height: 0.02)
            )
        }
    }

    /// Shoulders back — rear delts (mirror of front delts).
    private static func makeShouldersBack() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.14, y: 0.16, width: 0.16, height: 0.10))
            p.addEllipse(in: CGRect(x: 0.70, y: 0.16, width: 0.16, height: 0.10))
        }
    }

    /// Triceps — back of upper arms.
    private static func makeTricepsBack() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.05, y: 0.26, width: 0.14, height: 0.14))
            p.addEllipse(in: CGRect(x: 0.81, y: 0.26, width: 0.14, height: 0.14))
        }
    }

    /// Glutes — two rounded humps below lower back.
    private static func makeGlutesBack() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.27, y: 0.48, width: 0.22, height: 0.14))
            p.addEllipse(in: CGRect(x: 0.51, y: 0.48, width: 0.22, height: 0.14))
        }
    }

    /// Hamstrings — back of upper legs.
    private static func makeHamstringsBack() -> Path {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: 0.30, y: 0.60, width: 0.16, height: 0.18),
                cornerSize: CGSize(width: 0.04, height: 0.04)
            )
            p.addRoundedRect(
                in: CGRect(x: 0.54, y: 0.60, width: 0.16, height: 0.18),
                cornerSize: CGSize(width: 0.04, height: 0.04)
            )
        }
    }

    /// Calves back — fuller than front (calf bellies bulge backward).
    private static func makeCalvesBack() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.30, y: 0.78, width: 0.16, height: 0.14))
            p.addEllipse(in: CGRect(x: 0.54, y: 0.78, width: 0.16, height: 0.14))
        }
    }

    /// Forearms back — back of lower arms.
    private static func makeForearmsBack() -> Path {
        Path { p in
            p.addEllipse(in: CGRect(x: 0.06, y: 0.40, width: 0.13, height: 0.13))
            p.addEllipse(in: CGRect(x: 0.81, y: 0.40, width: 0.13, height: 0.13))
        }
    }
}
