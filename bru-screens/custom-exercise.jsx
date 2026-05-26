// Phase 1 · Custom Exercise · create form
// Save is blocked until at least one primary muscle is mapped.

function BruCustomExerciseScreen() {
  return (
    <BruPhone>
      <BruHeader left="CANCEL" center="New exercise" right="SAVE" />

      <div style={{ flex: 1, overflow: 'auto' }}>
        {/* Name */}
        <div style={{ padding: '14px 16px', borderBottom: `1px solid ${BRU.hair}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, fontWeight: 700, letterSpacing: 1.2 }}>NAME</div>
          <input
            defaultValue="Snatch-Grip Pull"
            style={{
              width: '100%', border: 'none', background: 'transparent',
              fontFamily: BRU.display, fontSize: 28, lineHeight: 1.1,
              letterSpacing: 0.5, color: BRU.ink, outline: 'none',
              padding: '4px 0', marginTop: 6, textTransform: 'uppercase',
              fontWeight: 400, boxSizing: 'border-box',
            }}
          />
        </div>

        {/* Type radio grid */}
        <BruSectionHead>Classification</BruSectionHead>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr',
          gap: 0, borderBottom: `1px solid ${BRU.ink}` }}>
          {[
            { l: 'EQUIPMENT', v: 'Barbell', open: true },
            { l: 'MECHANIC',  v: 'Compound' },
            { l: 'PATTERN',   v: 'Vertical pull' },
            { l: 'TEMPO',     v: 'Standard' },
            { l: 'BAR WT',    v: '45 lb' },
            { l: 'INCREMENT', v: '5 lb' },
          ].map((f, i) => (
            <div key={i} style={{
              padding: '10px 16px',
              borderBottom: i < 4 ? `1px solid ${BRU.hair}` : 'none',
              borderRight: i % 2 === 0 ? `1px solid ${BRU.hair}` : 'none',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            }}>
              <div>
                <div style={{ fontSize: 9, color: BRU.muted, fontWeight: 700, letterSpacing: 1.2 }}>{f.l}</div>
                <div style={{ fontSize: 14, fontWeight: 600, marginTop: 2 }}>{f.v}</div>
              </div>
              <span style={{ fontSize: 16, color: BRU.muted }}>›</span>
            </div>
          ))}
        </div>

        {/* Primary muscle */}
        <BruSectionHead right="Required">Primary muscle stimulus</BruSectionHead>
        <div style={{ padding: '12px 16px' }}>
          {[
            { name: 'BACK · LATS',        weight: 1.0, primary: true },
            { name: 'TRAPS',              weight: 0.8, primary: true },
          ].map((m, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 10,
              padding: '8px 0', borderBottom: `1px solid ${BRU.hair}`,
            }}>
              <BruChip fill color={BRU.signal}>PRIMARY</BruChip>
              <span style={{ flex: 1, fontSize: 13, fontWeight: 600 }}>{m.name}</span>
              {/* Inline slider rendered as numbered ticks */}
              <div style={{ display: 'flex', gap: 2 }}>
                {[0.25, 0.5, 0.75, 1.0].map(v => (
                  <div key={v} style={{
                    width: 22, height: 22, border: `1px solid ${BRU.ink}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 10, fontWeight: 700,
                    background: m.weight === v ? BRU.ink : 'transparent',
                    color: m.weight === v ? BRU.paper : BRU.ink,
                  }}>{v}</div>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Secondary muscles */}
        <BruSectionHead>Secondary stimulus</BruSectionHead>
        <div style={{ padding: '12px 16px' }}>
          {[
            { name: 'BICEPS',      weight: 0.5 },
            { name: 'FOREARMS',    weight: 0.25 },
            { name: 'REAR DELTS',  weight: 0.25 },
          ].map((m, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 10,
              padding: '8px 0', borderBottom: i < 2 ? `1px solid ${BRU.hair}` : 'none',
            }}>
              <BruChip>SECONDARY</BruChip>
              <span style={{ flex: 1, fontSize: 13, fontWeight: 600 }}>{m.name}</span>
              <div style={{ display: 'flex', gap: 2 }}>
                {[0.25, 0.5, 0.75, 1.0].map(v => (
                  <div key={v} style={{
                    width: 22, height: 22, border: `1px solid ${BRU.ink}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 10, fontWeight: 700,
                    background: m.weight === v ? BRU.ink : 'transparent',
                    color: m.weight === v ? BRU.paper : BRU.ink,
                  }}>{v}</div>
                ))}
              </div>
            </div>
          ))}
          <div style={{ marginTop: 12, padding: '8px 0', textAlign: 'center',
            border: `2px dashed ${BRU.ink}`,
            fontSize: 11, fontWeight: 700, letterSpacing: 1.5 }}>
            + ADD MUSCLE
          </div>
        </div>
      </div>

      {/* Status footer */}
      <div style={{
        borderTop: `2px solid ${BRU.ink}`,
        background: BRU.signal, color: BRU.paper, padding: '10px 16px',
        display: 'flex', justifyContent: 'space-between',
        fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
      }}>
        <span>VALID · 2 PRIMARY MAPPED</span>
        <span>READY TO SAVE</span>
      </div>
      <BruButton>Save exercise ▸</BruButton>
      <div style={{ height: 24 }} />
    </BruPhone>
  );
}

window.BruCustomExerciseScreen = BruCustomExerciseScreen;
