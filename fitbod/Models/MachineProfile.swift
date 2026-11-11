// MachineProfile.swift
// fitbod
//
// A machine the lifter has named (RM-066): a maker, a model, or both. A
// logged exercise points at the machine it was done on
// (`SessionExercise.machine`), so a brand machine never becomes a separate
// exercise in the library, and choosing a machine in one workout changes no
// other workout.
//
// A model without a maker is the lifter's own name for the machine
// ("Blue sled, Gym 2").

import Foundation
import SwiftData

@Model
public final class MachineProfile {
    @Attribute(.unique) public var id: UUID = UUID()
    /// Who made it: a `MachineBrand` raw value or a name the lifter typed.
    public var manufacturer: String? = nil
    /// The model, or the lifter's own name for a machine without a maker.
    public var model: String? = nil
    public var createdAt: Date = Date.now

    /// The logged exercises done on this machine. Deleting the machine
    /// leaves them without one.
    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.machine)
    public var logs: [SessionExercise]? = []

    public init() {}
}

extension MachineProfile {
    /// "Arsenal Strength Reloaded Linear Hack Squat", "Cybex", or the
    /// lifter's own name. A model that already starts with its maker's name
    /// does not repeat it.
    public var displayName: String {
        Self.displayName(manufacturer: manufacturer, model: model)
    }

    static func displayName(manufacturer: String?, model: String?) -> String {
        guard let manufacturer else { return model ?? "" }
        guard let model else { return manufacturer }
        if model.lowercased().hasPrefix(manufacturer.lowercased()) { return model }
        return "\(manufacturer) \(model)"
    }

    /// Text as a machine name stores it: trimmed, inner runs of spaces made
    /// one, nil when nothing is left.
    static func cleaned(_ text: String?) -> String? {
        let words = (text ?? "").split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    /// Two names for one machine match when they show the same name, whatever
    /// their case and spacing: the maker "Panatta" with the model "Super Hack
    /// Squat" is the machine named "Panatta Super Hack Squat" with no maker.
    func matches(manufacturer: String?, model: String?) -> Bool {
        Self.shownName(manufacturer: self.manufacturer, model: self.model)
            == Self.shownName(manufacturer: manufacturer, model: model)
    }

    private static func shownName(manufacturer: String?, model: String?) -> String {
        displayName(manufacturer: cleaned(manufacturer), model: cleaned(model)).lowercased()
    }
}
