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
/// `draft.imageData`; shows a preview thumbnail when set with a
/// remove-overlay button. When unset, shows a single "Add Photo"
/// `PhotosPicker` button.
struct CustomExerciseImagePicker: View {
    @Bindable var draft: CustomExerciseDraft
    @State private var selection: PhotosPickerItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = draft.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        Button(role: .destructive) {
                            draft.imageData = nil
                            selection = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .font(.title2)
                                .padding(8)
                        }
                        .accessibilityLabel("Remove image")
                    }
            }

            PhotosPicker(
                selection: $selection,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    draft.imageData == nil ? "Add Photo" : "Change Photo",
                    systemImage: "photo"
                )
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

#Preview("Image picker — empty") {
    Form {
        CustomExerciseImagePicker(draft: CustomExerciseDraft())
    }
}
