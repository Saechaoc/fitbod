// Main canvas — all Fitbod UI screens, organized by phase.
// Top section keeps the 5 visual directions; below it, the Brutalist app fully built out.

function PhoneFrame({ children, dark = false }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: dark ? '#000' : '#F2F2F7', overflow: 'hidden',
    }}>
      {children}
      {/* dynamic island */}
      <div style={{
        position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)',
        width: 126, height: 37, borderRadius: 24, background: '#000', zIndex: 99,
        pointerEvents: 'none',
      }} />
      {/* home indicator */}
      <div style={{
        position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)',
        width: 134, height: 5, borderRadius: 100,
        background: dark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.35)',
        zIndex: 99, pointerEvents: 'none',
      }} />
    </div>
  );
}

function Phone({ children }) {
  return (
    <div style={{ background: '#F0EDE5', borderRadius: 50, width: '100%', height: '100%',
      overflow: 'hidden' }}>
      <PhoneFrame>{children}</PhoneFrame>
    </div>
  );
}

const SIZE = { width: 393, height: 852 };

function App() {
  return (
    <DesignCanvas>
      {/* ═══════════════════════════════════════════════
          SECTION 1 — Five visual directions (the original)
          ═══════════════════════════════════════════════ */}
      <DCSection
        id="directions"
        title="Active session · five visual directions"
        subtitle="The same prescriptive top set, five different aesthetics. Tap LOG SET to fire the rest timer."
      >
        <DCArtboard id="terminal" label="A · Data terminal" {...SIZE}
          style={{ background: '#FAFAF7', borderRadius: 50 }}>
          <PhoneFrame><TerminalVariant /></PhoneFrame>
        </DCArtboard>

        <DCArtboard id="brutalist" label="B · Brutalist" {...SIZE}
          style={{ background: '#F0EDE5', borderRadius: 50 }}>
          <PhoneFrame><BrutalistVariant /></PhoneFrame>
        </DCArtboard>

        <DCArtboard id="soft" label="C · Soft iOS" {...SIZE}
          style={{ background: '#F2F2F7', borderRadius: 50 }}>
          <PhoneFrame><SoftVariant /></PhoneFrame>
        </DCArtboard>

        <DCArtboard id="dark" label="D · Dark garage" {...SIZE}
          style={{ background: '#0A0908', borderRadius: 50 }}>
          <PhoneFrame dark><DarkVariant /></PhoneFrame>
        </DCArtboard>

        <DCArtboard id="editorial" label="E · Editorial" {...SIZE}
          style={{ background: '#F7F1E5', borderRadius: 50 }}>
          <PhoneFrame><EditorialVariant /></PhoneFrame>
        </DCArtboard>
      </DCSection>

      {/* ═══════════════════════════════════════════════
          BRUTALIST · FULL APP
          ═══════════════════════════════════════════════ */}

      <DCSection
        id="phase-1"
        title="Phase 1 · Foundation + Exercise Library"
        subtitle="~800-exercise seed · multi-facet filter · custom exercises · indexed schema"
      >
        <DCArtboard id="library" label="Library · search + facets" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruLibraryScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="exercise-detail" label="Exercise · intent-split history" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruExerciseDetailScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="custom-exercise" label="Custom exercise · muscle stim." {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruCustomExerciseScreen /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="phase-2"
        title="Phase 2 · Core Loop · program + sessions"
        subtitle="Block-aware program tab (renamed from Routines) · routine builder · snapshot sessions · rest timer w/ Live Activity"
      >
        <DCArtboard id="today" label="Today · home" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruTodayScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="program" label="Program · active block + week + library" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruProgramScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="program-empty" label="Program · no-program empty state" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruProgramScreen state="empty" /></Phone>
        </DCArtboard>
        <DCArtboard id="program-newmenu" label="Program · + NEW menu" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruProgramScreen state="newmenu" /></Phone>
        </DCArtboard>
        <DCArtboard id="program-swipe" label="Program · row swipe" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruProgramScreen state="swipe" /></Phone>
        </DCArtboard>
        <DCArtboard id="program-context" label="Program · long-press menu" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruProgramScreen state="context" /></Phone>
        </DCArtboard>
        <DCArtboard id="routine-builder" label="Routine builder · single screen (PIVOT)" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruRoutineBuilderScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="new-routine-empty" label="New routine · blank state" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruNewRoutineScreen state="empty" /></Phone>
        </DCArtboard>
        <DCArtboard id="new-routine-named" label="New routine · named, 1 exercise" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruNewRoutineScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="exercise-picker" label="Exercise picker sheet · multi-select" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruExercisePickerSheet /></Phone>
        </DCArtboard>
        <DCArtboard id="modal-new-folder" label="New folder sheet" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruNewFolderSheet /></Phone>
        </DCArtboard>
        <DCArtboard id="modal-move" label="Move routine sheet" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruMoveRoutineSheet /></Phone>
        </DCArtboard>
        <DCArtboard id="modal-superset" label="Superset assignment sheet" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruSupersetAssignSheet /></Phone>
        </DCArtboard>
        <DCArtboard id="modal-discard" label="Discard changes dialog" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruDiscardConfirm /></Phone>
        </DCArtboard>
        <DCArtboard id="modal-delete-routine" label="Delete routine alert" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruDeleteRoutineAlert /></Phone>
        </DCArtboard>
        <DCArtboard id="modal-delete-folder" label="Delete folder · blocked" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruDeleteFolderBlockedAlert /></Phone>
        </DCArtboard>
        <DCArtboard id="active-session" label="Active session · top set" {...SIZE}
          style={{ borderRadius: 50 }}>
          <PhoneFrame><BrutalistVariant /></PhoneFrame>
        </DCArtboard>
        <DCArtboard id="history" label="Session history" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruSessionHistoryScreen /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="phase-3"
        title="Phase 3 · Smart prescription + warm-ups"
        subtitle="RPE autoreg · double progression · plate calculator · warm-up ramps · 'why this weight?'"
      >
        <DCArtboard id="why-weight" label="Why this weight · ramp" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruWhyWeightScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="plate-calc" label="Plate calculator + inventory" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruPlateCalcScreen /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="phase-4"
        title="Phase 4 · Periodization · blocks + phases"
        subtitle="Training blocks · phase navigation · deload-aware · end-of-block review"
      >
        <DCArtboard id="block-overview" label="Block overview · this week" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruBlockOverviewScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="block-builder" label="Block builder · phase editor" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruBlockBuilderScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="new-block-empty" label="New block · blank state" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruNewBlockScreen state="empty" /></Phone>
        </DCArtboard>
        <DCArtboard id="new-block-named" label="New block · named, ready to save" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruNewBlockScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="new-block-editphase" label="New block · edit phase sheet" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruNewBlockScreen state="editphase" /></Phone>
        </DCArtboard>
        <DCArtboard id="block-review" label="End-of-block review" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruBlockReviewScreen /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="phase-5"
        title="Phase 5 · Fatigue model + plateau detection"
        subtitle="Stimulus-weighted volume · MEV/MAV/MRV bars · muscle heatmap · stall detection"
      >
        <DCArtboard id="volume" label="Weekly volume · MEV→MRV" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruVolumeScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="heatmap" label="Muscle heatmap · front + back" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruHeatmapScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="plateau" label="Plateau detected · advisory" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruPlateauScreen /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection
        id="phase-6"
        title="Phase 6 · Progress views + export"
        subtitle="Per-exercise intent-split charts · PRs · weekly recap · CSV/JSON export · restore"
      >
        <DCArtboard id="progress" label="Exercise progress · intent split" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruProgressChartScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="recap" label="Weekly recap · auto-surfaced" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruWeeklyRecapScreen /></Phone>
        </DCArtboard>
        <DCArtboard id="settings" label="Settings · export · backup" {...SIZE}
          style={{ borderRadius: 50 }}>
          <Phone><BruSettingsScreen /></Phone>
        </DCArtboard>
      </DCSection>

    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
