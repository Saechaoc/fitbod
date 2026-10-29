// Phase 2 + 4 · Create flows
// What happens when "+ New block" / "+ New routine" / "+ Add exercise"
// is tapped. Single-screen forms with smart defaults — the brutalist version
// of a wizard.

// ─────────────────────────────────────────────────────────────
// NEW BLOCK · single-screen creator
// ─────────────────────────────────────────────────────────────
// Four phase types mapped onto BRU's existing signal palette (no foreign
// blues/purples) — the colour ties each card to its timeline segment.
// Accumulation is a restrained navy — NOT black, which is reserved for the
// app's structural chrome (frames, text, the Save surface). A real hue keeps
// repeated Accumulation phases legible against the black timeline frame.
const PHASE_TYPE = {
  Accumulation: { color: '#274C78', desc: 'Build volume' },
  Intensification: { color: BRU.signal, desc: 'Build strength' },
  Deload: { color: BRU.green, desc: 'Recover' },
  Peak: { color: BRU.amber, desc: 'Realize' }
};
const PHASE_ORDER = ['Accumulation', 'Intensification', 'Deload', 'Peak'];

// One-time press feedback for tappable phase cards.
if (typeof document !== 'undefined' && !document.getElementById('bru-create-styles')) {
  const s = document.createElement('style');
  s.id = 'bru-create-styles';
  s.textContent =
    '.bru-phase-card{transition:background .12s,transform .06s}' +
    '.bru-phase-card:active{background:#E8E4D9;transform:translateY(1px)}';
  document.head.appendChild(s);
}

// Brutalist stepper — bordered − / value / + on hard squares.
function BruStepper({ value, big = false }) {
  const btn = {
    width: big ? 40 : 30, height: big ? 40 : 30, flexShrink: 0,
    border: `1.5px solid ${BRU.ink}`, background: BRU.paper, color: BRU.ink,
    cursor: 'pointer', fontFamily: BRU.font, fontSize: big ? 20 : 16,
    fontWeight: 700, lineHeight: 1, display: 'flex',
    alignItems: 'center', justifyContent: 'center', padding: 0
  };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: big ? 14 : 8 }}>
      <button style={btn}>−</button>
      <span style={{ fontFamily: BRU.display, fontSize: big ? 30 : 24, lineHeight: 1,
        minWidth: big ? 64 : 44, textAlign: 'center',
        fontVariantNumeric: 'tabular-nums' }}>{value}</span>
      <button style={btn}>+</button>
    </div>);

}

function BruNewBlockScreen({ state = 'default' }) {
  const empty = state === 'empty';
  const editing = state === 'editphase';

  const phases = [
  { id: 1, type: 'Accumulation', wks: 2, vol: '+20%', int: '70%' },
  { id: 2, type: 'Intensification', wks: 2, vol: 'Hold', int: '85%' },
  { id: 3, type: 'Deload', wks: 1, vol: '−50%', int: '70%' },
  { id: 4, type: 'Peak', wks: 1, vol: '−20%', int: '95%' },
  { id: 5, type: 'Accumulation', wks: 1, vol: '+10%', int: '70%' }];

  const totalWeeks = phases.reduce((a, p) => a + p.wks, 0);

  return (
    <BruPhone time="" right={<span></span>}>
      <BruHeader
        left="PROGRAM"
        center={<span style={{ color: BRU.muted }}></span>}
        right={<span style={{ color: empty ? BRU.muted : BRU.signal }}>SAVE</span>} />
      

      <div style={{ flex: 1, overflow: 'auto', position: 'relative' }}>
        {/* NAME */}
        <div style={{ padding: '14px 16px 14px', borderBottom: `1px solid ${BRU.hair}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5, fontWeight: 700 }}>
            BLOCK NAME
          </div>
          <div style={{ marginTop: 4, display: 'flex', alignItems: 'baseline' }}>
            <span style={{ fontFamily: BRU.display, fontSize: 40, letterSpacing: 0.5,
              lineHeight: 0.9, color: empty ? BRU.faint : BRU.ink,
              textTransform: 'uppercase' }}>
              {empty ? 'Name this block' : 'Hypertrophy meso'}
            </span>
            {empty && <span style={{
              display: 'inline-block', width: 3, height: 34,
              background: BRU.ink, marginLeft: 3,
              animation: 'blink 1s steps(2,end) infinite'
            }} />}
          </div>
          {empty &&
          <div style={{ marginTop: 10, display: 'flex', gap: 5, flexWrap: 'wrap' }}>
              {['Hypertrophy meso', 'Linear strength', 'Off-season', 'Pre-meet'].map((s) =>
            <BruChip key={s}>{s}</BruChip>
            )}
            </div>
          }
        </div>

        {/* TOTAL WEEKS / DAYS PER WEEK */}
        <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
          <div style={{ flex: 1, padding: '10px 14px 12px', borderRight: `1px solid ${BRU.ink}` }}>
            <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5, fontWeight: 700 }}>
              TOTAL WEEKS
            </div>
            <BruDisplay size={34} color={empty ? BRU.faint : BRU.ink} style={{ marginTop: 4 }}>
              {empty ? '0' : totalWeeks}
            </BruDisplay>
            <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5,
              fontWeight: 700, marginTop: 7 }}>FROM PHASES</div>
          </div>
          <div style={{ flex: 1, padding: '10px 14px 12px' }}>
            <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5, fontWeight: 700 }}>
              DAYS / WEEK
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
              <BruStepper value="4" />
            </div>
          </div>
        </div>

        {/* PREVIEW · colour-coded timeline + legend */}
        <div style={{ padding: '12px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
          <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1.5, color: BRU.muted, marginBottom: 8 }}>PREVIEW</div>
          {empty ?
          <div style={{ height: 40, border: `1.5px dashed ${BRU.faint}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: BRU.mono, fontSize: 10, color: BRU.faint, letterSpacing: 1 }}>
              ADD PHASES TO BUILD THE TIMELINE
            </div> :

          <>
              {/* segments separated by the black frame colour showing through the gaps */}
              <div style={{ display: 'flex', gap: 2, height: 34,
              border: `1.5px solid ${BRU.ink}`, background: BRU.ink }}>
                {phases.map((p, i) => {
                const t = PHASE_TYPE[p.type];
                return (
                  <div key={i} style={{
                    flex: p.wks, background: t.color, color: BRU.paper,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 9, fontWeight: 700, letterSpacing: 1, overflow: 'hidden'
                  }}>
                      {p.wks >= 2 ? p.type.slice(0, 5).toUpperCase() : ''}
                    </div>);

              })}
              </div>
              {/* week ruler — one W-prefixed marker per phase start, no duplicate trailing label */}
              <div style={{ display: 'flex', marginTop: 5 }}>
                {phases.map((p, i) => {
                const start = phases.slice(0, i).reduce((a, x) => a + x.wks, 0) + 1;
                return (
                  <div key={i} style={{ flex: p.wks, fontFamily: BRU.mono,
                    fontSize: 9, color: BRU.muted, letterSpacing: 0.5 }}>
                      W{start}
                    </div>);

              })}
              </div>
              <div style={{ fontFamily: BRU.mono, fontSize: 9, color: BRU.muted,
              marginTop: 9, letterSpacing: 0.3 }}>
                Vol Δ vs base · Int = % of training max
              </div>
            </>
          }
        </div>

        {/* PHASES */}
        <BruSectionHead right="+ ADD PHASE">
          Phases · {empty ? 0 : phases.length}
        </BruSectionHead>

        {empty ?
        <div style={{ padding: '24px 24px 28px', display: 'flex', flexDirection: 'column',
          alignItems: 'center', gap: 16, textAlign: 'center' }}>
            <div style={{ width: 64, height: 64, border: `3px dashed ${BRU.ink}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <BruDisplay size={36} color={BRU.faint}>0</BruDisplay>
            </div>
            <div>
              <BruDisplay size={24}>No phases yet</BruDisplay>
              <div style={{ fontSize: 12, color: BRU.muted, marginTop: 6, lineHeight: 1.5 }}>
                Add phases to shape the block — or start from a preset
                like linear, daily-undulating, or block periodization.
              </div>
            </div>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', justifyContent: 'center' }}>
              {PHASE_ORDER.map((name) =>
            <span key={name} style={{ display: 'flex', alignItems: 'center', gap: 6,
              border: `1.5px solid ${BRU.ink}`, padding: '6px 10px',
              fontSize: 11, fontWeight: 700, letterSpacing: 0.5, cursor: 'pointer' }}>
                  <span style={{ width: 9, height: 9, background: PHASE_TYPE[name].color }} />
                  + {name}
                </span>
            )}
            </div>
          </div> :

        <>
            {/* Scannable phase cards — colour-tied, tap to edit */}
            <div style={{ padding: '12px 12px 4px', display: 'flex',
            flexDirection: 'column', gap: 10 }}>
              {phases.map((ph, i) => {
              const t = PHASE_TYPE[ph.type];
              const armed = editing && i === 0;
              return (
                <div key={ph.id} className="bru-phase-card" style={{
                  border: `${armed ? 2 : 1.5}px solid ${BRU.ink}`,
                  background: armed ? BRU.bg2 : BRU.paper, cursor: 'pointer'
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10,
                    padding: '10px 12px' }}>
                      <div style={{ width: 32, height: 32, flexShrink: 0,
                      background: t.color, color: BRU.paper,
                      fontFamily: BRU.display, fontSize: 18, lineHeight: 1,
                      display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        {String(i + 1).padStart(2, '0')}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <span style={{ fontSize: 15, fontWeight: 600 }}>{ph.type}</span>
                          {ph.type === 'Deload' &&
                        <BruChip color={BRU.green}>DELOAD</BruChip>}
                        </div>
                        <div style={{ fontSize: 11, color: BRU.muted, marginTop: 1 }}>
                          {t.desc}
                        </div>
                      </div>
                      {/* reorder handle — visually distinct from the edit chevron */}
                      <span className="bru-phase-grip" title="Drag to reorder"
                      style={{ color: BRU.faint, fontSize: 13, letterSpacing: 1,
                        lineHeight: 1, cursor: 'grab' }}>⋮⋮</span>
                      {/* edit affordance — tap card or chevron to open Edit Phase */}
                      <span style={{ color: BRU.ink2, fontSize: 22, lineHeight: 1,
                        fontWeight: 300, marginLeft: 2 }}>›</span>
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
                    borderTop: `1px solid ${BRU.hair}` }}>
                      {[['WEEKS', ph.wks], ['VOL', ph.vol], ['INT', ph.int]].map(([l, v], j) =>
                    <div key={l} style={{ padding: '8px 12px',
                      borderLeft: j ? `1px solid ${BRU.hair}` : 'none' }}>
                          <div style={{ fontSize: 8, letterSpacing: 1.2, fontWeight: 700,
                        color: BRU.muted }}>{l}</div>
                          <div style={{ fontFamily: BRU.display, fontSize: 20, lineHeight: 1,
                        marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>{v}</div>
                        </div>
                    )}
                    </div>
                  </div>);

            })}
            </div>
            {/* Add phase */}
            <div style={{ margin: '4px 12px 16px', border: `2px dashed ${BRU.ink}`,
            padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10,
            fontSize: 12, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase' }}>
              <span style={{ fontFamily: BRU.display, fontSize: 20, lineHeight: 1 }}>+</span>
              <span>Add phase</span>
              <span style={{ marginLeft: 'auto', fontSize: 9, color: BRU.muted }}>↘ PRESETS</span>
            </div>
          </>
        }
      </div>

      {/* Footer · CANCEL | SAVE TEMPLATE */}
      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md" style={{ flex: 1, borderRight: `2px solid ${BRU.ink}` }}>
          Cancel
        </BruButton>
        <BruButton kind="primary" size="md" style={{ flex: 1.3 }}>
          Save template
        </BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />

      {/* Edit-phase sheet — overlays the whole screen */}
      {editing &&
      <BruDim opacity={0.4}>
          <BruEditPhaseSheet phase={phases[0]} />
        </BruDim>
      }
    </BruPhone>);

}

// Edit Phase bottom sheet — every setting for one phase in one place.
// Steppers live here, not duplicated on every card.
function BruEditPhaseSheet({ phase }) {
  const t = PHASE_TYPE[phase.type];
  return (
    <div style={{
      background: BRU.bg, color: BRU.ink, borderTop: `4px solid ${BRU.ink}`,
      animation: 'sheetIn 240ms cubic-bezier(.2,.6,.2,1)'
    }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '7px 0 5px' }}>
        <div style={{ width: 48, height: 4, background: BRU.faint }} />
      </div>

      {/* sheet header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10,
        padding: '6px 16px 12px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ width: 32, height: 32, background: t.color, color: BRU.paper,
          fontFamily: BRU.display, fontSize: 18, lineHeight: 1,
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>01</div>
        <span style={{ fontFamily: BRU.display, fontSize: 26, lineHeight: 1,
          textTransform: 'uppercase', flex: 1 }}>Edit phase</span>
        <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1,
          color: BRU.signal, textTransform: 'uppercase' }}>Done</span>
      </div>

      {/* TYPE */}
      <div style={{ padding: '14px 16px', borderBottom: `1px solid ${BRU.hair}`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.5,
          color: BRU.muted }}>TYPE</span>
        <span style={{ display: 'flex', alignItems: 'center', gap: 8,
          border: `1.5px solid ${BRU.ink}`, padding: '6px 10px', cursor: 'pointer' }}>
          <span style={{ width: 10, height: 10, background: t.color }} />
          <span style={{ fontSize: 13, fontWeight: 600 }}>{phase.type}</span>
          <span style={{ color: BRU.muted, fontSize: 11 }}>▾</span>
        </span>
      </div>

      {/* WEEKS / VOLUME / INTENSITY steppers */}
      {[
      { label: 'WEEKS', sub: null, value: phase.wks },
      { label: 'VOLUME', sub: 'vs base', value: phase.vol },
      { label: 'INTENSITY', sub: '% of training max', value: phase.int }].
      map((row, i) =>
      <div key={row.label} style={{ padding: '14px 16px',
        borderBottom: i < 2 ? `1px solid ${BRU.hair}` : `2px solid ${BRU.ink}`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.5,
            color: BRU.muted }}>{row.label}</div>
            {row.sub && <div style={{ fontSize: 10, color: BRU.faint, marginTop: 2 }}>{row.sub}</div>}
          </div>
          <BruStepper value={row.value} big />
        </div>
      )}

      {/* Delete */}
      <div style={{ padding: 16 }}>
        <button style={{
          width: '100%', border: `1.5px solid ${BRU.signal}`,
          background: `${BRU.signal}14`, color: BRU.signal,
          padding: '13px 0', cursor: 'pointer', fontFamily: BRU.font,
          fontSize: 13, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase'
        }}>Delete phase</button>
      </div>
      <div style={{ height: 20 }} />
    </div>);

}

// ─────────────────────────────────────────────────────────────
// NEW ROUTINE · single-screen creator (used when "+ New routine" tapped)
// ─────────────────────────────────────────────────────────────
function BruNewRoutineScreen({ state = 'default' }) {
  const empty = state === 'empty';
  return (
    <BruPhone>
      <BruHeader left="‹ Program" center="New routine" right={
      <span style={{ color: empty ? BRU.muted : BRU.signal }}>SAVE</span>
      } />

      {/* NAME — prompted cursor */}
      <div style={{ padding: '14px 16px 12px', borderBottom: `1px solid ${BRU.ink}` }}>
        <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>
          ROUTINE NAME
        </div>
        <div style={{ marginTop: 6, display: 'flex', alignItems: 'baseline' }}>
          <span style={{ fontFamily: BRU.display, fontSize: 32, letterSpacing: 0.5,
            lineHeight: 1, color: empty ? BRU.muted : BRU.ink,
            textTransform: 'uppercase' }}>
            {empty ? 'Name your routine' : 'Push C'}
          </span>
          <span style={{
            display: 'inline-block', width: 3, height: 30,
            background: BRU.ink, marginLeft: 2,
            animation: 'blink 1s steps(2,end) infinite'
          }} />
        </div>
        {empty ?
        <div style={{ marginTop: 8, display: 'flex', gap: 5, flexWrap: 'wrap' }}>
            {['Push A', 'Pull A', 'Legs A', 'Upper', 'Lower',
          'Full body'].map((s) =>
          <BruChip key={s}>{s}</BruChip>
          )}
          </div> :

        <div style={{ marginTop: 8, display: 'flex', gap: 5 }}>
            <BruChip>FOLDER · UPPER HYPERTROPHY</BruChip>
          </div>
        }
      </div>

      {/* PIVOT — routine-level intent + progression */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ flex: 1, padding: '10px 14px', borderRight: `1px solid ${BRU.ink}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>
            SESSION INTENT
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between',
            alignItems: 'baseline', marginTop: 4 }}>
            <BruDisplay size={20}>{empty ? 'Pick one' : 'Hypertrophy'}</BruDisplay>
            <span style={{ color: BRU.muted, fontSize: 14 }}>›</span>
          </div>
        </div>
        <div style={{ flex: 1, padding: '10px 14px' }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>
            PROGRESSION
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between',
            alignItems: 'baseline', marginTop: 4 }}>
            <BruDisplay size={20}>{empty ? 'Default' : 'Double prog.'}</BruDisplay>
            <span style={{ color: BRU.muted, fontSize: 14 }}>›</span>
          </div>
        </div>
      </div>

      {/* Day tabs only if part of a multi-day routine */}
      <div style={{ padding: '10px 16px', borderBottom: `2px solid ${BRU.ink}`,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5 }}>
          DAYS · 1
        </div>
        <BruChip>+ ADD DAY</BruChip>
      </div>

      {/* Exercises — empty state vs one added */}
      <div style={{ flex: 1, overflow: 'auto' }}>
        {empty ?
        // No exercises yet
        <div style={{ padding: '32px 24px', display: 'flex', flexDirection: 'column',
          alignItems: 'center', gap: 18, textAlign: 'center' }}>
            <div style={{ width: 72, height: 72, border: `3px dashed ${BRU.ink}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <BruDisplay size={40} color={BRU.muted}>0</BruDisplay>
            </div>
            <div>
              <BruDisplay size={26}>No exercises yet</BruDisplay>
              <div style={{ fontSize: 12, color: BRU.muted, marginTop: 6, lineHeight: 1.5 }}>
                Pick lifts from your 812-exercise library. You can reorder
                and set up supersets after.
              </div>
            </div>
            <button style={{
            background: BRU.signal, color: BRU.paper, border: 'none',
            padding: '14px 24px', cursor: 'pointer',
            fontFamily: BRU.display, fontSize: 22, letterSpacing: 1,
            textTransform: 'uppercase'
          }}>+ Add first exercise ▸</button>
          </div> :

        <>
            {/* Just added Bench Press */}
            <div style={{ padding: '12px 16px', borderBottom: `1px solid ${BRU.hair}` }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontFamily: BRU.display, fontSize: 24, lineHeight: 1, width: 26 }}>01</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>Bench Press</div>
                  <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                  textTransform: 'uppercase', marginTop: 2 }}>Defaults · 3 × 8 · RPE 8</div>
                </div>
                <BruChip fill color={BRU.signal} style={{ fontSize: 8 }}>JUST ADDED</BruChip>
              </div>
            </div>
            {/* Inline add */}
            <div style={{
            margin: 12, border: `2px dashed ${BRU.ink}`, padding: '14px 16px',
            display: 'flex', alignItems: 'center', gap: 10,
            fontSize: 13, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase'
          }}>
              <span style={{ fontFamily: BRU.display, fontSize: 22, lineHeight: 1 }}>+</span>
              <span>Add another exercise</span>
              <span style={{ marginLeft: 'auto', color: BRU.muted, fontSize: 10 }}>↘ LIBRARY</span>
            </div>
          </>
        }
      </div>

      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md">Cancel</BruButton>
        <BruButton kind={empty ? 'ghost' : 'primary'} size="md"
        style={empty ? { color: BRU.muted } : null}>
          {empty ? 'Add exercises first ↑' : 'Save routine ▸'}
        </BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>);

}

// ─────────────────────────────────────────────────────────────
// EXERCISE PICKER · sheet over the routine builder
// Used by both new + edit. Multi-select, then "Add N exercises".
// ─────────────────────────────────────────────────────────────
function BruExercisePickerSheet() {
  const results = [
  { name: 'Bench Press', muscle: 'CHEST', equip: 'BARBELL', selected: true, count: 247 },
  { name: 'Bench Press · Incline', muscle: 'CHEST', equip: 'BARBELL', selected: false, count: 41 },
  { name: 'Bench Press · DB', muscle: 'CHEST', equip: 'DB', selected: true, count: 18 },
  { name: 'Bent-Over Row', muscle: 'BACK', equip: 'BARBELL', selected: false, count: 92 },
  { name: 'Bent-Over Row · Pendlay', muscle: 'BACK', equip: 'BARBELL', selected: false, count: 0 },
  { name: 'Bicep Curl · DB', muscle: 'BICEPS', equip: 'DB', selected: false, count: 64 },
  { name: 'Bicep Curl · Cable', muscle: 'BICEPS', equip: 'CABLE', selected: false, count: 12 }];


  return (
    <BruPhone>
      <div style={{
        position: 'absolute', inset: 0, background: BRU.bg, zIndex: 0,
        display: 'flex', flexDirection: 'column', padding: '54px 0 0', boxSizing: 'border-box'
      }}>
        <BruHeader left="‹ Program" center="New routine" right="SAVE" />
        <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
          <BruDisplay size={26} style={{ lineHeight: 1 }}>Push C</BruDisplay>
        </div>
        <div style={{ padding: 16, color: BRU.muted, fontSize: 13 }}>
          (0 exercises)
        </div>
      </div>

      <BruDim>
        <BruSheet
          subtitle="New routine / + Add exercise"
          title="Pick exercises"
          height="86%"
          footer={<>
            <BruButton kind="ghost" size="md">Cancel</BruButton>
            <BruButton kind="signal" size="md">Add 2 exercises ▸</BruButton>
          </>}>
          {/* Search bar */}
          <div style={{
            padding: '10px 16px', borderBottom: `2px solid ${BRU.ink}`,
            display: 'flex', alignItems: 'center', gap: 10,
            position: 'sticky', top: 0, background: BRU.bg, zIndex: 2
          }}>
            <span style={{ fontFamily: BRU.display, fontSize: 18, lineHeight: 1 }}>🔍︎</span>
            <input defaultValue="b"
            style={{ flex: 1, border: 'none', background: 'transparent',
              fontFamily: BRU.font, fontSize: 16, fontWeight: 500,
              color: BRU.ink, outline: 'none' }} />
            <span style={{ fontFamily: BRU.mono, fontSize: 10, color: BRU.muted }}>
              7 / 812
            </span>
          </div>

          {/* Filter chips */}
          <div style={{ padding: '10px 16px', borderBottom: `2px solid ${BRU.ink}`,
            display: 'flex', gap: 5, overflowX: 'auto', whiteSpace: 'nowrap',
            position: 'sticky', top: 47, background: BRU.bg, zIndex: 2
          }}>
            <BruChip fill>All</BruChip>
            <BruChip>Chest</BruChip>
            <BruChip>Back</BruChip>
            <BruChip>+ Equipment</BruChip>
            <BruChip>Custom</BruChip>
          </div>

          {/* Letter section */}
          <div style={{ padding: '6px 16px', background: BRU.bg2,
            borderBottom: `1px solid ${BRU.ink}`,
            fontFamily: BRU.display, fontSize: 16, lineHeight: 1 }}>B</div>

          {results.map((e, i) =>
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '24px 1fr auto',
            gap: 10, alignItems: 'center',
            padding: '11px 16px', borderBottom: `1px solid ${BRU.hair}`,
            background: e.selected ? `${BRU.signal}10` : 'transparent',
            cursor: 'pointer'
          }}>
              <div style={{
              width: 22, height: 22, border: `2px solid ${BRU.ink}`,
              background: e.selected ? BRU.signal : 'transparent',
              color: BRU.paper, display: 'flex',
              alignItems: 'center', justifyContent: 'center',
              fontSize: 12, fontWeight: 800
            }}>{e.selected ? '✓' : ''}</div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600 }}>{e.name}</div>
                <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
                  <BruChip>{e.muscle}</BruChip>
                  <BruChip>{e.equip}</BruChip>
                </div>
              </div>
              <span style={{ fontFamily: BRU.mono, fontSize: 11, color: BRU.muted }}>
                {e.count}×
              </span>
            </div>
          )}

          {/* Sticky selection count */}
          <div style={{
            position: 'sticky', bottom: 0, background: BRU.ink, color: BRU.paper,
            padding: '10px 16px',
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            fontSize: 11, letterSpacing: 1.2, fontWeight: 700
          }}>
            <span>SELECTED · 2</span>
            <span style={{ fontFamily: BRU.mono, color: BRU.signal }}>
              BENCH (BB), BENCH (DB)
            </span>
          </div>
        </BruSheet>
      </BruDim>
    </BruPhone>);

}

Object.assign(window, {
  BruNewBlockScreen, BruNewRoutineScreen, BruExercisePickerSheet
});