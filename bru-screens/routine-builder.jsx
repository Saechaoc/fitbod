// Phase 2 · Routine Builder
// Single-screen builder · per-exercise prescription · supersets · drag-reorder

function BruRoutineBuilderScreen() {
  return (
    <BruPhone right={<span>SAVE</span>}>
      <BruHeader left="‹ Back" center="Edit routine" right="•••" />

      {/* Routine name + intent */}
      <div style={{ padding: '14px 16px 12px', borderBottom: `2px solid ${BRU.ink}` }}>
        <BruDisplay size={32} style={{ whiteSpace: 'nowrap', lineHeight: 1 }}>Upper hypertrophy</BruDisplay>
        <div style={{ display: 'flex', gap: 6, marginTop: 10, flexWrap: 'wrap' }}>
          <BruChip fill>Hypertrophy</BruChip>
          <BruChip>4 days / wk</BruChip>
          <BruChip>~52 min</BruChip>
          <BruChip color={BRU.signal}>Linked → Block 03</BruChip>
        </div>
      </div>

      {/* Day tabs */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        {[
          { id: 'a', label: 'PUSH A', active: true },
          { id: 'b', label: 'PULL A' },
          { id: 'c', label: 'PUSH B' },
          { id: 'd', label: 'PULL B' },
          { id: 'add', label: '+', accent: true },
        ].map(t => (
          <div key={t.id} style={{
            flex: t.id === 'add' ? '0 0 36px' : 1,
            padding: '10px 4px', textAlign: 'center', cursor: 'pointer',
            fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
            borderRight: t.id !== 'add' ? `1px solid ${BRU.ink}` : 'none',
            background: t.active ? BRU.ink : 'transparent',
            color: t.active ? BRU.paper : (t.accent ? BRU.signal : BRU.ink),
          }}>{t.label}</div>
        ))}
      </div>

      {/* Exercises */}
      <div style={{ flex: 1, overflow: 'hidden' }}>
        {/* Single exercise — Bench Press */}
        <div style={{ padding: '12px 16px', borderBottom: `1px solid ${BRU.hair}` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontFamily: BRU.display, fontSize: 26, lineHeight: 1, width: 28 }}>01</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2 }}>Bench Press</div>
              <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                textTransform: 'uppercase', marginTop: 1 }}>Barbell · top set + back-off</div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2,
              color: BRU.muted, fontSize: 12 }}>
              <span>⋮⋮</span>
            </div>
          </div>
          {/* Prescription pills row */}
          <div style={{ display: 'flex', gap: 5, marginTop: 8, flexWrap: 'wrap' }}>
            <BruChip>6–8 reps</BruChip>
            <BruChip>RPE 8–9</BruChip>
            <BruChip color={BRU.signal}>RPE autoreg</BruChip>
            <BruChip>3 min rest</BruChip>
            <BruChip>Plate ½ lb</BruChip>
          </div>
          {/* Set rows */}
          <div style={{ marginTop: 10, border: `1.5px solid ${BRU.ink}` }}>
            {[
              { kind: 'W/UP', reps: 8,  rpe: 4 },
              { kind: 'W/UP', reps: 6,  rpe: 5 },
              { kind: 'WORK', reps: 8,  rpe: 7 },
              { kind: 'WORK', reps: 8,  rpe: 8 },
              { kind: 'TOP',  reps: 8,  rpe: 9, signal: true },
              { kind: 'BACK', reps: 10, rpe: 8 },
            ].map((s, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '24px 60px 1fr 1fr',
                gap: 6, alignItems: 'center', padding: '5px 8px',
                borderBottom: i < 5 ? `1px solid ${BRU.hair}` : 'none',
                background: s.signal ? `${BRU.signal}0F` : 'transparent',
              }}>
                <span style={{ fontFamily: BRU.mono, fontSize: 10 }}>S{i+1}</span>
                <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
                  color: s.signal ? BRU.signal : BRU.ink }}>{s.kind}</span>
                <span style={{ fontFamily: BRU.display, fontSize: 18, textAlign: 'right',
                  fontVariantNumeric: 'tabular-nums' }}>×{s.reps}</span>
                <span style={{ fontFamily: BRU.display, fontSize: 18, textAlign: 'right',
                  fontVariantNumeric: 'tabular-nums',
                  color: s.signal ? BRU.signal : BRU.ink }}>@{s.rpe}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Superset bracket — Incline + Fly */}
        <div style={{
          padding: '12px 16px 12px 28px', borderBottom: `1px solid ${BRU.hair}`,
          position: 'relative',
        }}>
          <div style={{
            position: 'absolute', left: 12, top: 12, bottom: 12, width: 8,
            borderTop: `2px solid ${BRU.signal}`,
            borderBottom: `2px solid ${BRU.signal}`,
            borderLeft: `2px solid ${BRU.signal}`,
          }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontFamily: BRU.display, fontSize: 26, lineHeight: 1, width: 28,
              color: BRU.signal }}>SS</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2 }}>Incline DB Press</div>
              <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                textTransform: 'uppercase', marginTop: 1 }}>3 × 10 · RPE 8 · Double progression</div>
            </div>
            <span style={{ color: BRU.muted, fontSize: 12 }}>⋮⋮</span>
          </div>
          <div style={{ height: 1, background: BRU.hair, margin: '10px 0' }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontFamily: BRU.display, fontSize: 26, lineHeight: 1, width: 28 }}>02</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2 }}>Cable Fly</div>
              <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                textTransform: 'uppercase', marginTop: 1 }}>3 × 12 · RPE 9 · 60 s rest</div>
            </div>
            <span style={{ color: BRU.muted, fontSize: 12 }}>⋮⋮</span>
          </div>
        </div>

        {/* Compact rows */}
        {[
          { n: 3, name: 'Tricep Pushdown', spec: '4 × 12 · RPE 9' },
          { n: 4, name: 'OH Tricep Ext', spec: '3 × 15 · RPE 9 · cluster' },
        ].map(e => (
          <div key={e.n} style={{
            display: 'grid', gridTemplateColumns: '32px 1fr auto',
            gap: 10, alignItems: 'center',
            padding: '11px 16px', borderBottom: `1px solid ${BRU.hair}`,
          }}>
            <span style={{ fontFamily: BRU.display, fontSize: 22, lineHeight: 1 }}>
              {String(e.n).padStart(2, '0')}
            </span>
            <div>
              <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: -0.2 }}>{e.name}</div>
              <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                textTransform: 'uppercase', marginTop: 1 }}>{e.spec}</div>
            </div>
            <span style={{ color: BRU.muted, fontSize: 12 }}>⋮⋮</span>
          </div>
        ))}

        {/* Add exercise inline */}
        <div style={{
          margin: 12, border: `2px dashed ${BRU.ink}`, padding: '14px 16px',
          display: 'flex', alignItems: 'center', gap: 10,
          fontSize: 13, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase',
        }}>
          <span style={{ fontFamily: BRU.display, fontSize: 22, lineHeight: 1 }}>+</span>
          <span>Add exercise</span>
          <span style={{ marginLeft: 'auto', color: BRU.muted, fontSize: 10 }}>↘ FROM LIBRARY</span>
        </div>
      </div>

      {/* Bottom bar */}
      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md" style={{ borderRight: `2px solid ${BRU.ink}`, border: 'none' }}>
          Discard
        </BruButton>
        <BruButton kind="primary" size="md">Save routine ▸</BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruRoutineBuilderScreen = BruRoutineBuilderScreen;
