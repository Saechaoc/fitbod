// Phase 2 · Program tab (renamed from "Routines")
// Block = container that holds routines. Tab structure (top→bottom):
//   1. ACTIVE BLOCK hero (black slab, mirrors TodayView CTA)
//   2. THIS WEEK strip (7 rows MON–SUN)
//   3. ROUTINES library (demoted — storage shelf, not headline)
//
// state: 'default' | 'empty' | 'newmenu' | 'swipe' | 'context'
//   'empty' is the no-program state — the most important empty state
//   in the app, because every install hits it first.

function BruDayRow({ day, dot, routine, time, status, today }) {
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '32px 14px 1fr auto auto',
      gap: 10, alignItems: 'center',
      padding: '10px 16px',
      borderBottom: `1px solid ${BRU.hair}`,
      background: today ? `${BRU.signal}10` : 'transparent',
      position: 'relative',
      cursor: 'pointer',
    }}>
      {today && <div style={{
        position: 'absolute', left: 0, top: 0, bottom: 0,
        width: 4, background: BRU.signal,
      }} />}
      <span style={{ fontFamily: BRU.display, fontSize: 18, lineHeight: 1,
        color: status === 'rest' ? BRU.muted : BRU.ink, letterSpacing: 1 }}>
        {day}
      </span>
      <span style={{
        fontFamily: BRU.display, fontSize: 14, lineHeight: 1,
        color: status === 'done' ? BRU.ink
             : status === 'today' ? BRU.signal
             : status === 'rest' ? 'transparent'
             : BRU.muted,
      }}>{dot}</span>
      <span style={{ fontSize: 14, fontWeight: status === 'rest' ? 500 : 600,
        color: status === 'rest' ? BRU.muted : BRU.ink,
        letterSpacing: -0.2,
        textDecoration: status === 'done' ? 'line-through' : 'none',
        textDecorationColor: BRU.faint }}>
        {routine}
      </span>
      <span style={{ fontFamily: BRU.mono, fontSize: 10, color: BRU.muted,
        letterSpacing: 0.5, fontVariantNumeric: 'tabular-nums' }}>
        {time}
      </span>
      <span style={{
        fontSize: 9, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase',
        color: status === 'done' ? BRU.ink
             : today ? BRU.signal
             : BRU.muted,
        minWidth: 50, textAlign: 'right',
      }}>
        {status === 'done' ? '✓ LOGGED' : today ? 'TODAY ▸' : status === 'rest' ? 'REST' : ''}
      </span>
    </div>
  );
}

function BruRoutineRow({ n, name, ex, intent, intentColor, swipe, contextOpen, last = '4d ago' }) {
  return (
    <div style={{ position: 'relative', overflow: 'hidden',
      borderBottom: `1px solid ${BRU.hair}` }}>
      {/* Swipe actions track */}
      {swipe && (
        <div style={{
          position: 'absolute', top: 0, right: 0, bottom: 0,
          display: 'flex', alignItems: 'stretch',
        }}>
          <button style={{ width: 60, background: BRU.ink, color: BRU.paper,
            border: 'none', fontSize: 8, fontWeight: 700, letterSpacing: 1,
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 3, cursor: 'pointer' }}>
            <span style={{ fontFamily: BRU.display, fontSize: 14, lineHeight: 1 }}>⎘</span>
            DUPE
          </button>
          <button style={{ width: 60, background: BRU.amber, color: BRU.ink,
            border: 'none', fontSize: 8, fontWeight: 700, letterSpacing: 1,
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 3, cursor: 'pointer' }}>
            <span style={{ fontFamily: BRU.display, fontSize: 14, lineHeight: 1 }}>↦</span>
            MOVE
          </button>
          <button style={{ width: 60, background: BRU.signal, color: BRU.paper,
            border: 'none', fontSize: 8, fontWeight: 700, letterSpacing: 1,
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 3, cursor: 'pointer' }}>
            <span style={{ fontFamily: BRU.display, fontSize: 14, lineHeight: 1 }}>✕</span>
            DELETE
          </button>
        </div>
      )}

      <div style={{
        background: BRU.bg, padding: '10px 16px',
        transform: swipe ? 'translateX(-180px)' : 'none',
        transition: 'transform 200ms ease', position: 'relative',
        display: 'grid', gridTemplateColumns: '28px 1fr auto',
        gap: 10, alignItems: 'center',
      }}>
        <span style={{ fontFamily: BRU.display, fontSize: 20, lineHeight: 1, color: BRU.muted }}>
          {String(n).padStart(2, '0')}
        </span>
        <div>
          <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: -0.2 }}>{name}</div>
          <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
            textTransform: 'uppercase', marginTop: 2 }}>
            {ex} ex · last {last}
          </div>
        </div>
        <BruChip fill={!!intentColor} color={intentColor || BRU.ink} style={{ fontSize: 9 }}>
          {intent}
        </BruChip>
      </div>

      {contextOpen && (
        <div style={{ position: 'absolute', right: 12, top: 44, zIndex: 30 }}>
          <BruMenu items={[
            { label: 'Start workout', kbd: '▸' },
            { label: 'Duplicate', kbd: '⎘' },
            { label: 'Move to…', kbd: '↦' },
            { label: 'Edit', kbd: '✎' },
            { label: 'Delete', destructive: true, kbd: '✕' },
          ]} />
        </div>
      )}
    </div>
  );
}

function BruProgramScreen({ state = 'default' }) {
  const empty = state === 'empty';

  return (
    <BruPhone right={empty ? <span style={{ fontFamily: BRU.mono }}>setup</span>
      : <span style={{ fontFamily: BRU.mono }}>w3 d4</span>}>
      <BruHeader left="Program" right={
        <span style={{ color: state === 'newmenu' ? BRU.signal : BRU.ink }}>+ NEW</span>
      } />

      <div style={{ flex: 1, overflow: 'auto' }}>
        {empty ? (
          // ─── No-program empty state ───────────────────────────────
          <>
            {/* Hero */}
            <div style={{ padding: '22px 16px 18px', borderBottom: `2px solid ${BRU.ink}` }}>
              <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5, fontWeight: 700 }}>
                ACTIVE BLOCK · NONE
              </div>
              <BruDisplay size={68} style={{ marginTop: 6, lineHeight: 0.88, whiteSpace: 'nowrap' }}>
                No program
              </BruDisplay>
              <div style={{ fontSize: 13, color: BRU.ink2, lineHeight: 1.5, marginTop: 12 }}>
                A block schedules routines across weeks and phases —
                <strong> accumulation, intensification, peak, deload</strong>.
                You can also lift without a block, but Fitbod really earns
                its keep when you're running one.
              </div>
            </div>

            {/* Primary CTA: define a block */}
            <div style={{ padding: '16px' }}>
              <button style={{
                width: '100%', background: BRU.signal, color: BRU.paper,
                border: 'none', padding: '18px 0', cursor: 'pointer',
                fontFamily: BRU.display, fontSize: 28, letterSpacing: 1,
                textTransform: 'uppercase', display: 'flex',
                alignItems: 'center', justifyContent: 'center', gap: 10,
              }}>
                <span>+ Define block</span>
                <span>▸</span>
              </button>
              <div style={{ display: 'flex', gap: 5, marginTop: 10, flexWrap: 'wrap' }}>
                <BruChip>Weeks · 4–12</BruChip>
                <BruChip>Phases · 1–4</BruChip>
                <BruChip>Deload optional</BruChip>
                <BruChip>Custom</BruChip>
              </div>
            </div>

            {/* Or start from a template */}
            <BruSectionHead right="4 PRESETS">Or start from a template</BruSectionHead>
            {[
              { weeks: 5, name: 'Hypertrophy meso',  days: '4 / wk', level: 'INTERMEDIATE', popular: true,
                phases: 'ACCUM 3 · INTNS 1 · DELOAD 1' },
              { weeks: 4, name: 'Linear strength',   days: '3 / wk', level: 'BEGINNER',
                phases: 'BUILD 3 · TEST 1' },
              { weeks: 8, name: 'Powerbuilding',     days: '5 / wk', level: 'ADVANCED',
                phases: 'ACCUM 3 · INTNS 2 · PEAK 2 · DELOAD 1' },
              { weeks: 4, name: '5 / 3 / 1 cycle',    days: '4 / wk', level: 'INTERMEDIATE',
                phases: 'WEEK 1 · 2 · 3 · DELOAD' },
            ].map((p, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '60px 1fr auto',
                gap: 12, alignItems: 'center',
                padding: '14px 16px', borderBottom: `1px solid ${BRU.hair}`,
                cursor: 'pointer',
              }}>
                <BruDisplay size={32} style={{ lineHeight: 1 }}>{p.weeks}W</BruDisplay>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <span style={{ fontSize: 14, fontWeight: 600 }}>{p.name}</span>
                    {p.popular && <BruChip fill color={BRU.signal} style={{ fontSize: 8 }}>POPULAR</BruChip>}
                  </div>
                  <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                    textTransform: 'uppercase', marginTop: 2 }}>
                    {p.days} · {p.level}
                  </div>
                  <div style={{ fontFamily: BRU.mono, fontSize: 9, color: BRU.muted,
                    letterSpacing: 0.5, marginTop: 4 }}>
                    {p.phases}
                  </div>
                </div>
                <span style={{ color: BRU.muted, fontSize: 14 }}>›</span>
              </div>
            ))}

            {/* Side path */}
            <div style={{ padding: '14px 16px', borderTop: `2px solid ${BRU.ink}`,
              background: BRU.bg2, display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontFamily: BRU.display, fontSize: 18, lineHeight: 1, color: BRU.muted }}>↘</span>
              <div style={{ flex: 1, fontSize: 12, color: BRU.muted, letterSpacing: 0.5 }}>
                Just want to log without a program?
              </div>
              <BruChip>Log a workout</BruChip>
            </div>
          </>
        ) : (
          // ─── Default — active block + week + routines ─────────────
          <>
            {/* ACTIVE BLOCK · hero */}
            <div style={{ background: BRU.ink, color: BRU.paper,
              padding: '14px 16px 16px', cursor: 'pointer' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between',
                fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.7 }}>
                <span>● ACTIVE BLOCK · #03</span>
                <span style={{ color: BRU.signal }}>12 DAYS LEFT</span>
              </div>
              <BruDisplay size={36} color={BRU.paper}
                style={{ marginTop: 4, lineHeight: 1, whiteSpace: 'nowrap' }}>
                Hypertrophy meso
              </BruDisplay>
              {/* Phase ticker */}
              <div style={{ display: 'flex', marginTop: 12, gap: 3 }}>
                {[
                  { lbl: 'W1', kind: 'accum',  done: true },
                  { lbl: 'W2', kind: 'accum',  done: true },
                  { lbl: 'W3', kind: 'intns',  now: true },
                  { lbl: 'W4', kind: 'peak'  },
                  { lbl: 'W5', kind: 'deload', deload: true },
                ].map(w => (
                  <div key={w.lbl} style={{
                    flex: 1, padding: '6px 0', textAlign: 'center',
                    background: w.now ? BRU.signal
                             : w.done ? 'rgba(255,255,255,0.85)'
                             : 'transparent',
                    color: w.now ? BRU.paper : w.done ? BRU.ink : BRU.paper,
                    border: `1.5px solid ${w.now ? BRU.signal : 'rgba(255,255,255,0.4)'}`,
                    position: 'relative',
                  }}>
                    <div style={{ fontFamily: BRU.display, fontSize: 14, lineHeight: 1 }}>{w.lbl}</div>
                    <div style={{ fontSize: 7, fontWeight: 700, letterSpacing: 0.8,
                      marginTop: 2, opacity: 0.85 }}>
                      {w.kind.toUpperCase()}
                    </div>
                  </div>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 12, marginTop: 12, fontSize: 11,
                fontWeight: 700, letterSpacing: 1.2 }}>
                <span>PHASE · INTENSIFICATION</span>
                <span style={{ opacity: 0.5 }}>·</span>
                <span style={{ color: BRU.signal }}>VOL HOLD · INT 85%</span>
              </div>
            </div>

            {/* THIS WEEK · day strip */}
            <BruSectionHead right="MAY 22 — MAY 28">This week</BruSectionHead>
            <BruDayRow day="MON" dot="●" routine="Push A" time="52m"  status="done" />
            <BruDayRow day="TUE" dot="●" routine="Pull A" time="48m"  status="done" />
            <BruDayRow day="WED" dot="—" routine="Rest"   time=""     status="rest" />
            <BruDayRow day="THU" dot="◯" routine="Push B" time="~52m" status="today" today />
            <BruDayRow day="FRI" dot="—" routine="Rest"   time=""     status="rest" />
            <BruDayRow day="SAT" dot="◯" routine="Pull B" time="~48m" status="" />
            <BruDayRow day="SUN" dot="—" routine="Rest"   time=""     status="rest" />

            {/* ROUTINES library · demoted */}
            <BruSectionHead right={<span style={{ display: 'inline-flex', gap: 8 }}>
              <span>5</span><span style={{ color: BRU.muted }}>·</span><span>SEARCH ⌕</span>
            </span>}>
              Routines library
            </BruSectionHead>
            <BruRoutineRow n={1} name="Push A" ex={5}
              intent="COMPOUND" intentColor={BRU.signal} />
            <BruRoutineRow n={2} name="Pull A" ex={5}
              intent="COMPOUND" intentColor={BRU.signal} />
            <BruRoutineRow n={3} name="Push B" ex={5}
              intent="HYPERTROPHY"
              swipe={state === 'swipe'}
              contextOpen={state === 'context'} />
            <BruRoutineRow n={4} name="Pull B" ex={5} intent="HYPERTROPHY" />
            <BruRoutineRow n={5} name="Quick 30-min" ex={4} intent="ENDURANCE"
              last="2 wk ago" />

            {/* Footer hint */}
            <div style={{ padding: '14px 16px', borderTop: `1px solid ${BRU.hair}`,
              background: BRU.bg2, display: 'flex', justifyContent: 'space-between',
              alignItems: 'center', fontSize: 10, letterSpacing: 1, color: BRU.muted,
              fontWeight: 700 }}>
              <span>FOLDERS · 0</span>
              <BruChip>+ NEW FOLDER</BruChip>
            </div>
          </>
        )}
      </div>

      <BruTabBar active="program" />

      {/* "+ NEW" menu floating — now includes Block (Program tab pivot) */}
      {state === 'newmenu' && (
        <>
          <div style={{ position: 'absolute', inset: 0,
            background: 'rgba(10,10,10,0.35)', zIndex: 9 }} />
          <div style={{ position: 'absolute', top: 88, right: 12, zIndex: 30 }}>
            <BruMenu items={[
              { label: '+ New block' },
              { label: '+ New routine' },
            ]} />
          </div>
        </>
      )}
    </BruPhone>
  );
}

// Keep old name as alias so app.jsx artboards keep working.
window.BruProgramScreen = BruProgramScreen;
window.BruRoutinesListScreen = BruProgramScreen;
