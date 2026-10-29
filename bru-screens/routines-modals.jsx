// Phase 2 · Routine builder modals (rendered over a dimmed builder background).
// Five separate screens so each can be reviewed individually:
//   NewFolderSheet, MoveRoutineSheet, SupersetAssignSheet,
//   DiscardConfirmDialog, DeleteRoutineAlert, DeleteFolderBlockedAlert

function BuilderBackdrop() {
  // Cheap dimmed parent — solid block to imply the builder is underneath.
  return (
    <div style={{
      position: 'absolute', inset: 0, background: BRU.bg, zIndex: 0,
      display: 'flex', flexDirection: 'column', padding: '54px 0 0', boxSizing: 'border-box',
    }}>
      <BruHeader left="‹ Routines" center="Push A" right="SAVE" />
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ fontFamily: BRU.display, fontSize: 32, lineHeight: 1 }}>PUSH A</div>
        <div style={{ display: 'flex', gap: 5, marginTop: 8 }}>
          <BruChip fill>Hypertrophy</BruChip>
          <BruChip>Double prog.</BruChip>
        </div>
      </div>
      <div style={{ flex: 1, padding: 16, color: BRU.muted, fontSize: 13 }}>
        5 exercises · 21 sets
      </div>
    </div>
  );
}

function ListBackdrop() {
  return (
    <div style={{
      position: 'absolute', inset: 0, background: BRU.bg, zIndex: 0,
      display: 'flex', flexDirection: 'column', padding: '54px 0 0', boxSizing: 'border-box',
    }}>
      <BruHeader left="Program" right="+ NEW" />
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '12px 16px' }}>
        <div style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>
          ● ACTIVE BLOCK · #03
        </div>
        <BruDisplay size={26} color={BRU.paper}
          style={{ marginTop: 4, lineHeight: 1, whiteSpace: 'nowrap' }}>
          Hypertrophy meso
        </BruDisplay>
      </div>
      <div style={{ padding: 16, color: BRU.muted, fontSize: 13 }}>
        Push A, Pull A, Push B, Pull B · 5 routines
      </div>
    </div>
  );
}

// ─── New folder sheet ───────────────────────────────────────────────
function BruNewFolderSheet() {
  return (
    <BruPhone>
      <ListBackdrop />
      <BruDim>
        <BruSheet
          subtitle="Program / + New"
          title="New folder"
          footer={<>
            <BruButton kind="ghost" size="md">Cancel</BruButton>
            <BruButton kind="primary" size="md">Create folder ▸</BruButton>
          </>}>
          <div style={{ padding: '16px' }}>
            <div style={{ fontSize: 9, color: BRU.muted, fontWeight: 700, letterSpacing: 1.2 }}>
              FOLDER NAME
            </div>
            <div style={{ marginTop: 6, border: `2px solid ${BRU.ink}`, padding: '10px 12px',
              display: 'flex', alignItems: 'center', gap: 4 }}>
              <span style={{ fontFamily: BRU.display, fontSize: 22, letterSpacing: 0.5 }}>
                MEET PREP — APR'27
              </span>
              <span style={{ fontFamily: BRU.display, fontSize: 22,
                background: BRU.ink, color: BRU.bg, width: 2, animation: 'blink 1s steps(2,end) infinite' }}>&nbsp;</span>
            </div>
            <div style={{ marginTop: 8, fontSize: 11, color: BRU.muted, letterSpacing: 0.3 }}>
              Names must be unique within the parent folder.
            </div>

            {/* Suggestions */}
            <div style={{ marginTop: 18 }}>
              <div style={{ fontSize: 9, color: BRU.muted, fontWeight: 700, letterSpacing: 1.2 }}>
                SUGGESTED
              </div>
              <div style={{ marginTop: 8, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {['Hypertrophy', 'Strength', 'Power', 'Conditioning', 'Off-season',
                  'Pre-meet', 'Travel', 'Rehab'].map(s => (
                  <BruChip key={s}>{s}</BruChip>
                ))}
              </div>
            </div>
          </div>
        </BruSheet>
      </BruDim>
    </BruPhone>
  );
}

// ─── Move-routine sheet ─────────────────────────────────────────────
function BruMoveRoutineSheet() {
  const folders = [
    { name: 'Upper Hypertrophy · Block 03', count: 4, current: true, active: true },
    { name: 'Strength meet prep', count: 2 },
    { name: 'Conditioning', count: 0 },
    { name: 'Ungrouped', count: 2 },
    { name: 'Archive · 2025', count: 11, archive: true },
  ];
  return (
    <BruPhone>
      <ListBackdrop />
      <BruDim>
        <BruSheet
          subtitle='Program / "Push B"'
          title="Move to folder"
          footer={<>
            <BruButton kind="ghost" size="md">Cancel</BruButton>
            <BruButton kind="primary" size="md">Move ▸</BruButton>
          </>}>
          <div>
            {folders.map((f, i) => {
              const selected = i === 3; // Ungrouped pre-selected as the move target
              return (
                <div key={i} style={{
                  display: 'flex', alignItems: 'center', gap: 10,
                  padding: '14px 16px',
                  borderBottom: i < folders.length - 1 ? `1px solid ${BRU.hair}` : 'none',
                  background: selected ? `${BRU.signal}10` : 'transparent',
                  position: 'relative',
                }}>
                  {selected && <div style={{
                    position: 'absolute', left: 0, top: 0, bottom: 0,
                    width: 4, background: BRU.signal }} />}
                  <div style={{
                    width: 22, height: 22, border: `2px solid ${BRU.ink}`,
                    background: selected ? BRU.signal : 'transparent',
                    color: BRU.paper, display: 'flex',
                    alignItems: 'center', justifyContent: 'center',
                    fontSize: 12, fontWeight: 800,
                  }}>{selected ? '✓' : ''}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ fontSize: 14, fontWeight: 600,
                        opacity: f.archive ? 0.6 : 1 }}>{f.name}</span>
                      {f.current && <BruChip>HERE</BruChip>}
                      {f.active && <BruChip fill color={BRU.signal} style={{ fontSize: 8 }}>BLOCK</BruChip>}
                      {f.archive && <BruChip style={{ fontSize: 8 }}>ARCHIVE</BruChip>}
                    </div>
                    <div style={{ fontSize: 10, color: BRU.muted, marginTop: 2,
                      letterSpacing: 0.5, textTransform: 'uppercase' }}>
                      {f.count} ROUTINE{f.count === 1 ? '' : 'S'}
                    </div>
                  </div>
                </div>
              );
            })}

            {/* + new folder shortcut */}
            <div style={{ padding: '12px 16px', borderTop: `2px dashed ${BRU.ink}` }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontFamily: BRU.display, fontSize: 22, lineHeight: 1, color: BRU.signal }}>+</span>
                <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.2,
                  textTransform: 'uppercase', color: BRU.signal }}>
                  New folder
                </span>
              </div>
            </div>
          </div>
        </BruSheet>
      </BruDim>
    </BruPhone>
  );
}

// ─── Superset assignment sheet (in-builder, long-press) ─────────────
function BruSupersetAssignSheet() {
  const lifts = [
    { n: 1, name: 'Bench Press',     muscle: 'CHEST', selected: true, source: true },
    { n: 2, name: 'Incline DB Press', muscle: 'CHEST', selected: true, paired: 'A' },
    { n: 3, name: 'Cable Fly',        muscle: 'CHEST' },
    { n: 4, name: 'Tricep Pushdown',  muscle: 'TRICEPS' },
    { n: 5, name: 'OH Tricep Ext',    muscle: 'TRICEPS', tag: 'CLUSTER' },
  ];
  return (
    <BruPhone>
      <BuilderBackdrop />
      <BruDim>
        <BruSheet
          subtitle="Long-pressed: Incline DB Press"
          title="Add to superset"
          footer={<>
            <BruButton kind="ghost" size="md">Cancel</BruButton>
            <BruButton kind="signal" size="md">Pair 2 lifts ▸</BruButton>
          </>}>
          <div style={{ padding: '12px 16px 6px',
            fontSize: 11, color: BRU.muted, letterSpacing: 0.3, lineHeight: 1.5 }}>
            Pair 2–4 lifts. Sets alternate between members. Rest belongs to the last lift in the cluster.
          </div>

          {/* Lift checklist */}
          <div>
            {lifts.map((l, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '32px 28px 1fr auto',
                gap: 10, alignItems: 'center', padding: '10px 16px',
                borderBottom: i < lifts.length - 1 ? `1px solid ${BRU.hair}` : 'none',
                background: l.selected ? `${BRU.signal}10` : 'transparent',
              }}>
                <span style={{ fontFamily: BRU.display, fontSize: 20 }}>
                  {String(l.n).padStart(2, '0')}
                </span>
                <div style={{
                  width: 22, height: 22, border: `2px solid ${BRU.ink}`,
                  background: l.selected ? BRU.signal : 'transparent',
                  color: BRU.paper, display: 'flex',
                  alignItems: 'center', justifyContent: 'center',
                  fontSize: 12, fontWeight: 800,
                }}>{l.selected ? '✓' : ''}</div>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>{l.name}</div>
                  <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1, fontWeight: 700, marginTop: 2 }}>
                    {l.muscle}{l.source ? ' · SOURCE' : ''}{l.paired ? ` · PAIR ${l.paired}` : ''}
                  </div>
                </div>
                {l.tag && <BruChip>{l.tag}</BruChip>}
              </div>
            ))}
          </div>

          {/* Rest behavior */}
          <div style={{ borderTop: `2px solid ${BRU.ink}`, padding: '12px 16px',
            background: BRU.bg2 }}>
            <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>
              REST BEHAVIOR
            </div>
            <div style={{ display: 'flex', gap: 0, marginTop: 8,
              border: `2px solid ${BRU.ink}` }}>
              {['MINIMAL', 'STANDARD', 'EXTENDED'].map((r, i) => (
                <div key={r} style={{
                  flex: 1, padding: '8px 0', textAlign: 'center',
                  fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
                  background: i === 1 ? BRU.ink : 'transparent',
                  color: i === 1 ? BRU.paper : BRU.ink,
                  borderRight: i < 2 ? `2px solid ${BRU.ink}` : 'none',
                }}>{r}</div>
              ))}
            </div>
            <div style={{ marginTop: 6, fontFamily: BRU.mono, fontSize: 10,
              color: BRU.muted, letterSpacing: 0.5 }}>
              STANDARD · 0 S BETWEEN PAIR · 90 S AT CLUSTER END
            </div>
          </div>
        </BruSheet>
      </BruDim>
    </BruPhone>
  );
}

// ─── Discard-changes confirmation ──────────────────────────────────
function BruDiscardConfirm() {
  return (
    <BruPhone>
      <BuilderBackdrop />
      <BruAlert
        kind="destructive"
        title="Discard 4 changes?"
        body="You've reordered 2 lifts, edited Bench Press prescription, and added Cable Fly. None of this is saved yet."
        primary="Discard"
        secondary="Keep editing" />
    </BruPhone>
  );
}

// ─── Delete-routine alert ──────────────────────────────────────────
function BruDeleteRoutineAlert() {
  return (
    <BruPhone>
      <ListBackdrop />
      <BruAlert
        kind="destructive"
        title='Delete "Push B"?'
        body="Templates are deleted permanently. Past sessions that ran this routine are kept — they hold their own snapshot."
        primary="Delete"
        secondary="Cancel" />
    </BruPhone>
  );
}

// ─── Delete-folder blocked alert ───────────────────────────────────
function BruDeleteFolderBlockedAlert() {
  return (
    <BruPhone>
      <ListBackdrop />
      <BruAlert
        kind="destructive"
        blocked
        title='"Upper Hypertrophy" not empty'
        body="This folder holds 4 routines. Move or delete them before deleting the folder."
        primary="Delete blocked"
        secondary="Move routines" />
    </BruPhone>
  );
}

Object.assign(window, {
  BruNewFolderSheet, BruMoveRoutineSheet, BruSupersetAssignSheet,
  BruDiscardConfirm, BruDeleteRoutineAlert, BruDeleteFolderBlockedAlert,
});
