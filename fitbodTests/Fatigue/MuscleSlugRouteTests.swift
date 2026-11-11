//
//  MuscleSlugRouteTests.swift
//  fitbodTests
//
//  MuscleSlugRoute.detail(_) is the route both the volume bars and the
//  heatmap regions push: it must append onto a NavigationPath and compare
//  by its slug.
//

import Testing
import SwiftUI
@testable import fitbod

@Suite("MuscleSlugRoute")
struct MuscleSlugRouteTests {

    @Test("MuscleSlugRoute.detail is Hashable — can be appended to NavigationPath")
    func muscleSlugRouteIsHashable() {
        let route = MuscleSlugRoute.detail("chest")
        var path = NavigationPath()
        // appendElement requires the type to conform to Hashable — this compiles
        // only if MuscleSlugRoute: Hashable
        path.append(route)
        #expect(path.count == 1, "NavigationPath should have 1 element after appending MuscleSlugRoute.detail")
    }

    @Test("MuscleSlugRoute.detail carries the correct slug string")
    func muscleSlugRouteSlugPreserved() {
        let slug = "triceps"
        let route = MuscleSlugRoute.detail(slug)
        // Extract via pattern matching
        if case .detail(let extracted) = route {
            #expect(extracted == slug, "MuscleSlugRoute.detail must preserve the slug verbatim")
        } else {
            Issue.record("MuscleSlugRoute.detail pattern match failed")
        }
    }

    @Test("Two MuscleSlugRoute.detail with different slugs are not equal — distinct routes")
    func muscleSlugRouteDistinctSlugs() {
        let chest = MuscleSlugRoute.detail("chest")
        let triceps = MuscleSlugRoute.detail("triceps")
        #expect(chest != triceps, "Different slugs must produce distinct MuscleSlugRoute values")
    }

    @Test("Two MuscleSlugRoute.detail with same slug are equal — stable hash")
    func muscleSlugRouteEqualSlugs() {
        let a = MuscleSlugRoute.detail("chest")
        let b = MuscleSlugRoute.detail("chest")
        #expect(a == b, "Same slug must produce equal MuscleSlugRoute values for stable navigation")
    }
}
