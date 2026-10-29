# New Training Block UX Spec

## Objective

Redesign the New Block flow so users can create reusable training block templates, then start those blocks separately by attaching routines. The current screen mixes block naming, template selection, phase configuration, and active routine assignment into one dense interface. The new structure should clarify the difference between a reusable block template and an active training block.

## Core Product Model

### 1. Training Block Template

A reusable training structure that defines how a program should progress over time.

A template contains:

* Block name
* Total weeks
* Days per week
* Phase list
* Phase duration
* Phase goal
* Volume multiplier or adjustment
* Intensity target or adjustment
* Optional preset/category metadata

Examples:

* Hypertrophy Meso
* Linear Strength
* Powerbuilding
* Off-Season
* Pre-Meet

A block template is not necessarily active. It is a saved structure that can be reused later.

### 2. Active Training Block

An instance of a block template that the user has started.

An active block contains:

* Selected block template
* Start date
* Current week
* Current phase
* Attached routine or routines
* Training days
* Progression state
* Volume and intensity adjustments applied to attached routines

The active block is what drives weekly progression and modifies routine targets.

### 3. Routine Attachment

A connection between a routine and an active block.

A routine attachment contains:

* Routine ID
* Active block ID
* Scheduled training days
* Applied volume multiplier
* Applied intensity target
* Phase-specific behavior
* Current week context

Routines should not permanently belong to a reusable template. Instead, routines attach to an active block instance.

## UX Structure

The app should separate two flows:

## Flow 1: Create Block Template

Purpose: create or edit the reusable block structure.

Primary screen title:

* New Block
* Edit Block Template, when editing an existing template

Sections:

### Section 1: Block Name

The large “NAME YOUR BLOCK” text must be an editable SwiftUI text field, not static text.

Requirements:

* “BLOCK NAME” remains the small uppercase label.
* “NAME YOUR BLOCK” is placeholder text only.
* Tapping the large text area focuses the field and opens the keyboard.
* User input replaces the placeholder visually.
* The field binds to block template state.
* Validation treats the block name as empty until the user enters real text.
* The placeholder should not be saved as the block name.

### Section 2: Block Settings

Fields:

* Total Weeks
* Days Per Week

Requirements:

* Keep these as compact numeric controls.
* Maintain the current editorial visual style.
* These values should update the preview bar and phase validation.

### Section 3: Start From Template

The preset chips should no longer sit directly under the block name field.

Move presets into their own section called:

* START FROM TEMPLATE

Description:

* “Choose a preset or build from scratch.”

Preset options:

* Blank
* Hypertrophy Meso
* Linear Strength
* Powerbuilding
* Off-Season
* Pre-Meet

Behavior:

* Selecting a preset should populate total weeks, days per week, phases, volume adjustments, and intensity targets.
* The selected preset should be visibly active.
* Users can still edit all populated values after selecting a preset.
* Presets are starting points, not locked templates.

Layout guidance:

* Use a horizontal scroll row, segmented card row, or compact preset grid.
* Do not crowd the chips under the block name.
* The preset section should feel like an intentional setup step, not metadata tags.

### Section 4: Phases

Purpose: define how the block progresses.

Each phase should include:

* Phase number
* Phase name
* Phase goal/subtitle
* Duration in weeks
* Volume adjustment
* Intensity target
* Optional phase badge
* Drag/reorder handle
* Delete/edit affordance, where appropriate

Example phases:

1. Accumulation

   * Goal: Build Volume
   * Weeks: 2
   * Volume: +20%
   * Intensity: 70%

2. Intensification

   * Goal: Build Strength
   * Weeks: 2
   * Volume: Hold
   * Intensity: 85%

3. Deload

   * Goal: Recover
   * Weeks: 1
   * Volume: -50%
   * Intensity: 60%

Requirements:

* Phase rows should be compact and evenly spaced.
* Phase title and subtitle should sit close together.
* Metric boxes should sit close to the phase header.
* Divider spacing should be tight and intentional.
* The preview bar should update based on phase durations.
* Total phase weeks should match total block weeks or show validation feedback.

### Section 5: Add Phase

The Add Phase control should remain near the bottom of the phase list.

Requirements:

* Dashed border style is acceptable.
* It should sit close to the final phase row.
* Include a secondary Presets affordance if useful.
* Avoid excessive vertical padding.

## Flow 2: Start Block

Purpose: turn a reusable block template into an active training block.

This should be a separate screen or flow after template creation.

Primary screen title:

* Start Block

Sections:

### Section 1: Selected Template

Show the selected block template summary:

* Template name
* Total weeks
* Days per week
* Phase preview

### Section 2: Start Date

Allow the user to choose when the block begins.

Fields:

* Start date
* Optional starting week override

### Section 3: Attach Routine

Allow the user to attach one or more routines.

States:

* No routines attached yet
* One routine attached
* Multiple routines attached

Actions:

* Attach Routine
* Change Routine
* Remove Routine

Requirements:

* A block can be started without modifying the reusable template.
* Attached routines belong to the active block instance.
* The app should use the active block state to adjust volume, intensity, and progression targets.

### Section 4: Training Schedule

Allow the user to confirm training days.

Fields:

* Days per week
* Selected weekdays, if supported
* Routine-to-day mapping, if multiple routines are attached

### CTA

Primary action:

* START BLOCK

Secondary action:

* CANCEL

## Bottom CTA Behavior

On the Create Block Template screen:

Primary CTA should be one of:

* SAVE TEMPLATE
* CREATE TEMPLATE
* SAVE BLOCK

Avoid using “START BLOCK” on the template creation screen unless the user is actually creating an active block instance.

Disabled CTA states:

* If no name is entered: “NAME FIRST ↑”
* If phases are invalid: “FIX PHASES ↑”
* If total weeks does not match phase weeks: “CHECK WEEKS ↑”

## Visual Layout Requirements

The screen should preserve the strong editorial design language:

* Cream/off-white background
* Thin black dividers
* Condensed uppercase labels
* Large condensed block name text
* Compact controls
* Dense vertical rhythm
* High-contrast section bars
* Minimal rounded corners
* Strong grid alignment

Spacing requirements:

* Avoid default SwiftUI spacing where it creates excess air.
* Use explicit spacing tokens.
* Tighten spacing between labels, fields, chips, preview, and phase rows.
* Do not use unnecessary Spacer() elements that push sections apart.
* Section hierarchy should come from dividers, labels, and typography, not large padding gaps.

## Validation Requirements

Block template validation:

* Block name is required.
* Total weeks must be greater than 0.
* Days per week must be greater than 0.
* At least one phase is required.
* Sum of phase weeks should equal total weeks.
* Each phase must have a name.
* Each phase must have at least 1 week.
* Volume and intensity values must be valid according to the app’s progression rules.

Active block validation:

* Template is required.
* Start date is required.
* At least one routine should be attached before starting, unless the app intentionally supports starting empty.
* Training days should match or be compatible with days per week.

## Recommended Navigation

Recommended flow:

1. User taps New Block.
2. User creates a reusable block template.
3. User saves the template.
4. App asks whether they want to start it now.
5. User chooses attached routine and start date.
6. App creates an active block instance.
7. Routine views show active block context.

Example routine display once attached:

* Attached to: Hypertrophy Meso
* Week 2 of 5
* Current phase: Accumulation
* Volume: +20%
* Intensity target: 70%

## Acceptance Criteria

* The block name is a real SwiftUI text field.
* Placeholder text is not saved as the block name.
* Preset chips are moved out of the block name area into a dedicated Start From Template section.
* Presets populate block configuration but remain editable.
* The Create Block screen focuses on reusable template creation.
* Starting a block with routines happens in a separate Start Block flow.
* Routines attach to active block instances, not directly to reusable templates.
* The UI maintains the dense editorial style of the mock.
* Vertical spacing is tighter, consistent, and intentionally structured.
* CTA language reflects whether the user is saving a template or starting an active block.

