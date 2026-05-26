// Phase 2 · Home / Today
// Block-phase context + Today's workout + week strip + recent stats

function BruTodayScreen() {
  return (
    <BruPhone right={<span>● <span style={{ fontFamily: BRU.mono, marginLeft: 4 }}>w3</span></span>}>
      <BruHeader left="Fitbod / Today" right="Wed · May 22" />

      {/* Top stat strip */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ flex: 1, padding: '14px 16px', borderRight: `1px solid ${BRU.ink}` }}>
          <BruReadout label="Day streak" value="14" />
        </div>
        <div style={{ flex: 1, padding: '14px 16px', borderRight: `1px solid ${BRU.ink}` }}>
          <BruReadout label="Sessions" value="42" />
        </div>
        <div style={{ flex: 1, padding: '14px 16px' }}>
          <BruReadout label="W3 / 5" value="↑" color={BRU.signal} />
        </div>
      </div>

      {/* Block context */}
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
          <BruChip>Block</BruChip>
          <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2 }}>
            UPPER HYPERTROPHY
          </span>
          <BruChip color={BRU.signal} fill>Intensification</BruChip>
        </div>
        {/* Week ticker */}
        <div style={{ display: 'flex', marginTop: 12, gap: 4 }}>
          {[1,2,3,4,5].map(n => {
            const active = n === 3;
            const past = n < 3;
            const deload = n === 5;
            return (
              <div key={n} style={{
                flex: 1, height: 28,
                background: active ? BRU.ink : past ? BRU.faint : 'transparent',
                border: `1.5px solid ${active ? BRU.ink : past ? 'transparent' : BRU.ink}`,
                color: active ? BRU.paper : BRU.ink,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: BRU.display, fontSize: 16, lineHeight: 1,
                position: 'relative',
              }}>
                W{n}
                {deload && <span style={{
                  position: 'absolute', top: -7, right: -3,
                  fontSize: 7, fontWeight: 700, padding: '1px 3px',
                  background: BRU.signal, color: BRU.paper, letterSpacing: 1,
                }}>DL</span>}
              </div>
            );
          })}
        </div>
      </div>

      {/* TODAY'S WORKOUT — black slab CTA */}
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '18px 16px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>
          <span>NEXT</span>
          <span>DAY 01 / 04</span>
        </div>
        <BruDisplay size={56} color={BRU.paper} style={{ marginTop: 6 }}>
          Push A
        </BruDisplay>
        <div style={{ display: 'flex', gap: 18, marginTop: 12, fontSize: 11,
          fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase' }}>
          <span>5 exercises</span>
          <span style={{ opacity: 0.5 }}>·</span>
          <span>21 sets</span>
          <span style={{ opacity: 0.5 }}>·</span>
          <span>~52 min</span>
        </div>
        <BruButton kind="signal" size="lg" style={{ marginTop: 16 }}>
          Start workout ▸
        </BruButton>
      </div>

      {/* Up next list of exercises */}
      <BruSectionHead right="Tap to reorder">Lift list</BruSectionHead>
      <div style={{ flex: 1, overflow: 'hidden' }}>
        {[
          { n: 1, name: 'Bench Press', sets: '2 warm-up · 3 work · 1 back-off', kind: 'COMPOUND' },
          { n: 2, name: 'Incline DB Press', sets: '3 × 10 @ 8', kind: 'WORK' },
          { n: 3, name: 'Cable Fly', sets: '3 × 12 @ 9', kind: 'WORK' },
          { n: 4, name: 'Tricep Pushdown', sets: '4 × 12 @ 9', kind: 'WORK' },
          { n: 5, name: 'OH Tricep Ext', sets: '3 × 15 @ 9 · CLUSTER', kind: 'WORK' },
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
                textTransform: 'uppercase', marginTop: 1 }}>{e.sets}</div>
            </div>
            <BruChip color={e.kind === 'COMPOUND' ? BRU.signal : BRU.ink}>
              {e.kind}
            </BruChip>
          </div>
        ))}
      </div>

      <BruTabBar active="today" />
    </BruPhone>
  );
}

window.BruTodayScreen = BruTodayScreen;
