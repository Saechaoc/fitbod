// KeyboardVisibility.swift
// fitbod
//
// Whether the software keyboard is on screen, published by RootView.

import SwiftUI

extension EnvironmentValues {
    /// True while the software keyboard is on screen. `RootView` sets it;
    /// screens read it to hide bottom chrome (the tab bar, the rest-timer
    /// dock) that would otherwise ride up on the keyboard and cover the
    /// field being edited.
    @Entry var isKeyboardVisible = false
}
