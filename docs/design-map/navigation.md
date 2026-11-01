# Navigation

How the lifter reaches every screen, sheet, dialog and system sheet.
A rectangle is a screen, a rounded box is a sheet or a full-screen cover, a hexagon is a dialog or alert, and a box with double sides is drawn by iOS.
A solid arrow pushes a screen, a dotted arrow presents a sheet, cover, dialog or system sheet, and an arrow's label is the control the lifter taps.
The tab bar switches between the four tabs, so tab switches are not drawn.
Each screen file lists the same links under Entry points and Exits, and [conventions.md](conventions.md#mermaid) has the drawing rules.

## Launch and tabs

The app opens on Today, after the exercise library has loaded on the first launch.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    today["Today"]
  end
  subgraph tab_program["Program"]
    program["Program"]
  end
  subgraph tab_progress["Progress"]
    progress["Progress"]
  end
  subgraph tab_library["Library"]
    library["Library"]
  end
  preparing_library["Preparing library"]
  x_launch["App launch"]
  preparing_library -->|the library is ready| today
  x_launch -->|first launch or store reset| preparing_library
  x_launch -->|every launch after the first| today
```

## Today

Screens that live in the Today tab, with the screens elsewhere that open them or that they open. A screen that more than one tab reaches lives in the first tab its file lists.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    block_review(["Block review"])
    decimal_rpe_picker(["RPE"])
    dialog_workout_menu{{"Workout"}}
    fatigue_signals(["Fatigue signals"])
    history["History"]
    library_picker(["Add exercise"])
    logger["Workout"]
    notification_permission[["Send notifications"]]
    per_muscle_detail["Muscle detail"]
    per_set_note(["Set note"])
    pinned_note(["Pinned note"])
    rest_timer(["Rest timer"])
    settings(["Settings"])
    swap_exercise(["Swap exercise"])
    today["Today"]
    try_variation(["Try variation"])
    weekly_recap(["Weekly recap"])
    why_this_weight(["Why this weight"])
    workout_notes(["Workout notes"])
    workout_summary["Summary"]
  end
  subgraph tab_program["Program"]
    block_overview["Block overview"]
    new_block(["New block"])
    new_routine["New routine"]
    program["Program"]
    routine_editor["Routine"]
    session_editor(["Edit session"])
    session_template_detail["Session"]
  end
  subgraph tab_progress["Progress"]
    progress["Progress"]
  end
  subgraph tab_library["Library"]
    custom_exercise(["New exercise"])
    filter_picker(["Filter"])
  end
  subgraph tab_settings["Settings sheet"]
    component_gallery["Component gallery"]
    file_importer[["Files"]]
    plate_inventory["Plate inventory"]
    share_sheet[["Share sheet"]]
    volume_targets["Volume targets"]
  end
  preparing_library["Preparing library"]
  x_launch["App launch"]
  block_review -.->|Start next| new_block
  dialog_workout_menu -.->|Workout notes| workout_notes
  history -->|a workout row| workout_summary
  library_picker -.-> custom_exercise
  library_picker -.-> filter_picker
  logger -.-> decimal_rpe_picker
  logger -.-> fatigue_signals
  logger -.-> library_picker
  logger -.-> notification_permission
  logger -.->|Note for set n on a set row| per_set_note
  logger -.-> pinned_note
  logger -.-> rest_timer
  logger -.-> swap_exercise
  logger -.-> try_variation
  logger -.-> why_this_weight
  logger --> workout_summary
  preparing_library -->|the library is ready| today
  program -->|Resume on the resume banner| logger
  progress -->|Workouts row| history
  session_editor -.->|+ Add exercise FROM LIBRARY| library_picker
  session_template_detail --> logger
  settings --> component_gallery
  settings -.->|RESTORE in the Backup panel| file_importer
  settings --> plate_inventory
  settings -.-> share_sheet
  settings --> volume_targets
  today --> block_overview
  today -.-> block_review
  today -.-> fatigue_signals
  today -->|the SESSIONS stat| history
  today --> logger
  today -.-> new_block
  today --> new_routine
  today --> per_muscle_detail
  today --> routine_editor
  today --> session_template_detail
  today -.->|Settings header, left| settings
  today -.-> weekly_recap
  x_launch -->|every launch after the first| today
```

## Program

Screens that live in the Program tab, with the screens elsewhere that open them or that they open. A screen that more than one tab reaches lives in the first tab its file lists.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    block_review(["Block review"])
    library_picker(["Add exercise"])
    logger["Workout"]
    today["Today"]
  end
  subgraph tab_program["Program"]
    archived_routines["Archived routines"]
    block_overview["Block overview"]
    dialog_program_new{{"New"}}
    new_block(["New block"])
    new_block_add_phase_type(["Add phase"])
    new_block_duration(["Edit block duration"])
    new_block_phase_editor(["Phase editor"])
    new_block_split_picker(["Choose routine"])
    new_block_template(["Start from template"])
    new_routine["New routine"]
    preset_picker(["Choose preset"])
    program["Program"]
    routine_editor["Routine"]
    session_editor(["Edit session"])
    session_template_detail["Session"]
    slot_picker(["Add session"])
    split_picker(["Choose routine"])
    start_choice(["Create block"])
    superset_assignment(["Add to superset"])
    swap_confirm(["Start block?"])
    warmup_config(["Warm-up settings"])
  end
  block_overview -.-> new_block
  block_overview -.->|+ ATTACH ROUTINE| split_picker
  block_overview -.->|START BLOCK| swap_confirm
  block_review -.->|Start next| new_block
  dialog_program_new --> new_routine
  dialog_program_new -.->|+ New block| start_choice
  new_block -.->|+ ADD PHASE| new_block_add_phase_type
  new_block -.-> new_block_duration
  new_block -.-> new_block_phase_editor
  new_block -.-> new_block_split_picker
  new_block -.->|PRESET beside + ADD PHASE| new_block_template
  new_routine --> routine_editor
  preset_picker -.-> new_block
  program --> archived_routines
  program --> block_overview
  program -->|Resume on the resume banner| logger
  program -.-> new_block
  program --> new_routine
  program -->|a routine row in ROUTINES| routine_editor
  program -.-> start_choice
  routine_editor --> session_template_detail
  routine_editor -.-> slot_picker
  session_editor -.->|+ Add exercise FROM LIBRARY| library_picker
  session_editor -.-> superset_assignment
  session_editor -.-> warmup_config
  session_template_detail --> logger
  session_template_detail -.->|EDIT opens Edit session| session_editor
  slot_picker -.-> session_editor
  start_choice -.->|Blank Block| new_block
  start_choice -.->|Use Preset| preset_picker
  today --> block_overview
  today -.-> new_block
  today --> new_routine
  today --> routine_editor
  today --> session_template_detail
```

## Progress

Screens that live in the Progress tab, with the screens elsewhere that open them or that they open. A screen that more than one tab reaches lives in the first tab its file lists.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    history["History"]
  end
  subgraph tab_progress["Progress"]
    compare["This week vs last week"]
    exercise_progress["Exercise progress"]
    pr_session["PR workout"]
    progress["Progress"]
    prs["Personal records"]
    week_detail["Week detail"]
    weekly_tonnage["Weekly tonnage"]
  end
  subgraph tab_library["Library"]
    exercise_detail["Exercise"]
    exercise_history["Exercise history"]
  end
  exercise_detail -->|View progress chart| exercise_progress
  exercise_history -->|PROGRESS in the header| exercise_progress
  progress -->|This week vs last week| compare
  progress -->|an exercise row under Recent| exercise_progress
  progress -->|Workouts row| history
  progress -->|Personal Records| prs
  progress -->|Weekly Tonnage| weekly_tonnage
  prs -->|any PR row| pr_session
  weekly_tonnage --> week_detail
```

## Library

Screens that live in the Library tab, with the screens elsewhere that open them or that they open. A screen that more than one tab reaches lives in the first tab its file lists.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    library_picker(["Add exercise"])
  end
  subgraph tab_progress["Progress"]
    exercise_progress["Exercise progress"]
  end
  subgraph tab_library["Library"]
    custom_exercise(["New exercise"])
    equipment_picker(["Equipment"])
    exercise_detail["Exercise"]
    exercise_history["Exercise history"]
    filter_picker(["Filter"])
    library["Library"]
    muscle_picker(["Add muscle"])
    photos_picker[["Photos"]]
  end
  custom_exercise -.->|The EQUIPMENT row| equipment_picker
  custom_exercise -.->|+ ADD MUSCLE| muscle_picker
  custom_exercise -.-> photos_picker
  exercise_detail -.-> custom_exercise
  exercise_detail -->|View all history| exercise_history
  exercise_detail -->|View progress chart| exercise_progress
  exercise_history -->|PROGRESS in the header| exercise_progress
  library -.-> custom_exercise
  library -->|An exercise row| exercise_detail
  library -.-> filter_picker
  library_picker -.-> custom_exercise
  library_picker -.-> filter_picker
```

## Settings sheet

Settings opens as a sheet from Today, and these screens open inside it.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    settings(["Settings"])
  end
  subgraph tab_settings["Settings sheet"]
    add_plate(["Add plate"])
    component_gallery["Component gallery"]
    file_importer[["Files"]]
    plate_calculator(["Plate calculator"])
    plate_inventory["Plate inventory"]
    share_sheet[["Share sheet"]]
    volume_targets["Volume targets"]
  end
  plate_inventory -.-> add_plate
  plate_inventory -.->|in the header VoiceOver More| plate_calculator
  settings --> component_gallery
  settings -.->|RESTORE in the Backup panel| file_importer
  settings --> plate_inventory
  settings -.-> share_sheet
  settings --> volume_targets
```

## Dialogs and alerts

Every dialog and alert, beside the screen that shows it.

```mermaid
flowchart LR
  subgraph tab_today["Today"]
    dialog_couldnt_start_workout{{"Couldn't start workout"}}
    dialog_discard_workout{{"Discard workout?"}}
    dialog_discard_workout_slab{{"Discard workout?"}}
    dialog_finish_workout{{"Finish workout?"}}
    dialog_remove_exercise{{"Remove Barbell Bench Press - Medium Grip?"}}
    dialog_workout_in_progress{{"Workout in progress"}}
    dialog_workout_menu{{"Workout"}}
    logger["Workout"]
    today["Today"]
  end
  subgraph tab_program["Program"]
    archived_routines["Archived routines"]
    block_overview["Block overview"]
    dialog_archive_routine{{"Archive routine?"}}
    dialog_archive_session{{"Archive this session?"}}
    dialog_cannot_archive_routine{{"Cannot archive routine"}}
    dialog_couldnt_save{{"Couldn't Save"}}
    dialog_discard_active{{"Discard active workout?"}}
    dialog_discard_block{{"Discard this block?"}}
    dialog_discard_changes_session{{"Discard changes?"}}
    dialog_end_block{{"End block?"}}
    dialog_program_new{{"New"}}
    dialog_remove_session{{"Remove Session?"}}
    dialog_replace_phases{{"Replace your phases?"}}
    dialog_save_routine_first{{"Save Routine First"}}
    dialog_session_in_use{{"Session is in use"}}
    dialog_session_menu{{"Session"}}
    new_block(["New block"])
    new_block_template(["Start from template"])
    new_routine["New routine"]
    program["Program"]
    routine_editor["Routine"]
    session_editor(["Edit session"])
    session_template_detail["Session"]
  end
  subgraph tab_library["Library"]
    custom_exercise(["New exercise"])
    dialog_changes_not_saved{{"Changes were not saved"}}
    dialog_custom_exercise_discard{{"Discard Changes?"}}
    dialog_delete_exercise{{"Delete 'Tour Custom Press'?"}}
  end
  subgraph tab_settings["Settings sheet"]
    dialog_reset_plate_inventory{{"Reset plate inventory?"}}
    dialog_reset_volume_targets{{"Reset all volume targets?"}}
    dialog_restore_complete{{"Restore complete"}}
    dialog_restore_confirm{{"Restore from backup?"}}
    dialog_restore_error{{"Finish your session first"}}
    file_importer[["Files"]]
    plate_inventory["Plate inventory"]
    volume_targets["Volume targets"]
  end
  archived_routines -.-> dialog_couldnt_save
  block_overview -.-> dialog_couldnt_save
  block_overview -.-> dialog_end_block
  custom_exercise -.-> dialog_changes_not_saved
  custom_exercise -.-> dialog_custom_exercise_discard
  custom_exercise -.-> dialog_delete_exercise
  dialog_archive_routine -.-> dialog_couldnt_save
  dialog_archive_session -.-> dialog_couldnt_save
  dialog_delete_exercise -.-> dialog_changes_not_saved
  dialog_end_block -.-> dialog_couldnt_save
  dialog_remove_session -.-> dialog_couldnt_save
  dialog_restore_confirm -.-> dialog_restore_complete
  dialog_restore_confirm -.-> dialog_restore_error
  dialog_session_menu -.-> dialog_archive_session
  dialog_session_menu -.-> dialog_couldnt_save
  dialog_session_menu -.-> dialog_session_in_use
  dialog_workout_menu -.-> dialog_discard_workout
  dialog_workout_menu -.-> dialog_finish_workout
  file_importer -.-> dialog_restore_confirm
  file_importer -.-> dialog_restore_error
  logger -.-> dialog_remove_exercise
  logger -.-> dialog_workout_menu
  new_block -.-> dialog_discard_block
  new_block_template -.-> dialog_replace_phases
  new_routine -.-> dialog_couldnt_save
  plate_inventory -.-> dialog_reset_plate_inventory
  program -.-> dialog_discard_active
  program -.-> dialog_program_new
  routine_editor -.-> dialog_archive_routine
  routine_editor -.-> dialog_cannot_archive_routine
  routine_editor -.-> dialog_couldnt_save
  routine_editor -.-> dialog_remove_session
  session_editor -.-> dialog_couldnt_save
  session_editor -.-> dialog_discard_changes_session
  session_editor -.-> dialog_save_routine_first
  session_editor -.-> dialog_session_menu
  session_template_detail -.-> dialog_couldnt_start_workout
  session_template_detail -.-> dialog_workout_in_progress
  today -.-> dialog_couldnt_start_workout
  today -.-> dialog_discard_workout_slab
  volume_targets -.-> dialog_reset_volume_targets
```
