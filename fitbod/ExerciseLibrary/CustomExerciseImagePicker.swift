//
//  CustomExerciseImagePicker.swift
//  fitbod
//
//  Wave-3 plan 03-04 — optional image attachment for the custom-
//  exercise editor. Native iOS-16+ `PhotosPicker` SwiftUI primitive;
//  NO `NSPhotoLibraryUsageDescription` Info.plist entry is required
//  (RESEARCH Pattern 7 + Assumption A6) because `PhotosPicker` runs
//  under the sandboxed `PHPickerViewController`, which scopes access
//  to the single image the user picked.
//
//  ## BRU layout (review item 20)
//
//  The picked image shows square-cornered inside a 2pt ink rule. Below it
//  sit BRU text controls, not SF Symbols: "+ ADD PHOTO" while there is no
//  image, then "CHANGE PHOTO" and "REMOVE PHOTO". At accessibility text
//  sizes the two controls stack.
//
//  ## Async data load (RESEARCH § Pattern 7 — anti-pattern call-out)
//
//  `PhotosPickerItem.loadTransferable(type: Data.self)` is async.
//  Calling it synchronously from `.onChange` would block the UI; the
//  pattern is:
//
//    .onChange(of: selection) { _, newValue in
//        Task {
//            if let data = try? await newValue?.loadTransferable(type: Data.self) {
//                draft.imageData = data
//            }
//        }
//    }
//
//  The fetched `Data` is written to `draft.imageData`; the editor's
//  `materialize(into:)` then writes it to the persisted
//  `Exercise.imageData` (which is `@Attribute(.externalStorage)` so
//  the blob lives outside the SQLite store).
//
//  ## What's deferred
//
//  - The UI-SPEC § Custom exercise editor mentions an action sheet
//    with "Take Photo / Choose from Library / Cancel". `PhotosPicker`
//    only surfaces the library, so the camera path is deferred per
//    plan "Out of Scope" — camera capture would require
//    `AVFoundation` and a custom camera UI.
//  - The UI-SPEC § Error states "Photo Access Required" alert is
//    dead code in v1 — `PhotosPicker` is sandbox-permission-free, so
//    the deny branch can never fire. The alert copy stays in UI-SPEC
//    as future-proofing for a possible camera-path implementation.
//

import SwiftUI
import PhotosUI

/// Optional-image picker for the custom-exercise editor. Binds to
/// `draft.imageData`; shows the image when set, with CHANGE PHOTO and
/// REMOVE PHOTO. When unset, shows a single "+ ADD PHOTO" `PhotosPicker`.
struct CustomExerciseImagePicker: View {
    @Bindable var draft: CustomExerciseDraft
    @State private var selection: PhotosPickerItem? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: BRUMetrics.Spacing.related) {
            if let data = draft.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .overlay(Rectangle().strokeBorder(Color.bruInk, lineWidth: BRUMetrics.Border.structural))
                    .accessibilityLabel("Exercise image")
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(spacing: BRUMetrics.Spacing.section))
            let pickerLabel = draft.imageData == nil ? "+ Add photo" : "Change photo"
            layout {
                PhotosPicker(
                    selection: $selection,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ImageTextControl(label: pickerLabel)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(draft.imageData == nil ? "Add photo" : "Change photo")

                if draft.imageData != nil {
                    Button {
                        draft.imageData = nil
                        selection = nil
                    } label: {
                        ImageTextControl(label: "Remove photo")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove image")
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            // Async load — PhotosPickerItem.loadTransferable is async
            // by design (the picker may return a remote-fetched asset).
            Task { @MainActor in
                if let data = try? await newValue?
                    .loadTransferable(type: Data.self)
                {
                    draft.imageData = data
                }
            }
        }
    }
}

/// A BRU text control's label: small uppercase signal text on a 44pt
/// target. A view of its own, because `PhotosPicker` builds its label
/// outside the main actor.
private struct ImageTextControl: View {
    let label: String

    var body: some View {
        Text(label)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruSignalText)
            .frame(minHeight: BRUMetrics.touchTarget)
            .contentShape(Rectangle())
    }
}

#Preview("Image picker — empty") {
    CustomExerciseImagePicker(draft: CustomExerciseDraft())
        .padding(16)
        .background(Color.bruPaper)
}
