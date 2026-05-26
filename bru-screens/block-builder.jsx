// Phase 4 · Block Builder
// Phase sequence editor · per-phase week + multipliers · linked routines

function BruBlockBuilderScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹" center="Edit block" right="SAVE" />

      {/* Title */}
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>BLOCK NAME</div>
        <BruDisplay size={32} style={{ whiteSpace: 'nowrap', lineHeight: 1, marginTop: 4 }}>Upper hypertrophy</BruDisplay>
        <div style={{ display: 'flex', gap: 5, marginTop: 8 }}>
          <BruChip>5 weeks</BruChip>
          <BruChip>4 days / wk</BruChip>
          <BruChip>Linear</BruChip>
          <BruChip color={BRU.signal}>Active</BruChip>
        </div>
      </div>

      {/* Timeline visual */}
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, fontWeight: 700, letterSpacing: 1.5, marginBottom: 8 }}>
          <span>TIMELINE</span>
          <span style={{ color: BRU.signal }}>NOW · W3</span>
        </div>
        <div style={{ display: 'flex', gap: 2, height: 56,
          border: `2px solid ${BRU.ink}` }}>
          {[
            { wks: 2, label: 'ACCUM',    fill: 'rgba(10,10,10,0.85)', past: true },
            { wks: 1, label: 'INTNS',    fill: BRU.signal,            now: true },
            { wks: 1, label: 'PEAK',     fill: 'rgba(10,10,10,0.25)' },
            { wks: 1, label: 'DELOAD',   fill: 'transparent', stripe: true },
          ].map((ph, i) => (
            <div key={i} style={{
              flex: ph.wks, position: 'relative',
              background: ph.stripe ?
                'repeating-linear-gradient(45deg, transparent 0 6px, rgba(10,10,10,0.18) 6px 12px)'
                : ph.fill,
              border: ph.now ? `2px solid ${BRU.ink}` : 'none',
              color: ph.past || ph.now ? BRU.paper : BRU.ink,
              display: 'flex', alignItems: 'flex-end', padding: 6,
              fontSize: 9, fontWeight: 700, letterSpacing: 1.2,
            }}>
              {ph.label}
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          marginTop: 6, fontFamily: BRU.mono, fontSize: 10, color: BRU.muted }}>
          <span>W1</span><span>W2</span><span>W3</span><span>W4</span><span>W5</span>
        </div>
      </div>

      {/* Phase rows */}
      <BruSectionHead right="+ ADD PHASE">Phases</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { id: 1, name: 'Accumulation', wks: 2, vol: '+20%', int: '70%', kind: 'BUILD VOLUME', done: true },
          { id: 2, name: 'Intensification', wks: 1, vol: 'Hold', int: '85%', kind: 'BUILD STRENGTH', now: true },
          { id: 3, name: 'Peak / Realization', wks: 1, vol: '−20%', int: '95%', kind: 'PEAK' },
          { id: 4, name: 'Deload', wks: 1, vol: '−50%', int: '60%', kind: 'RECOVER', deload: true },
        ].map(ph => (
          <div key={ph.id} style={{
            padding: '12px 16px', borderBottom: `1px solid ${BRU.hair}`,
            background: ph.now ? `${BRU.signal}0F` : 'transparent',
            position: 'relative',
          }}>
            {ph.now && (
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 4, background: BRU.signal }} />
            )}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontFamily: BRU.display, fontSize: 26, lineHeight: 1, width: 28 }}>
                {String(ph.id).padStart(2, '0')}
              </span>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{ph.name}</span>
                  {ph.now && <BruChip fill color={BRU.signal}>NOW</BruChip>}
                  {ph.done && <BruChip>DONE</BruChip>}
                  {ph.deload && <BruChip color={BRU.signal}>DELOAD</BruChip>}
                </div>
                <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                  textTransform: 'uppercase', marginTop: 2 }}>{ph.kind}</div>
              </div>
              <span style={{ color: BRU.muted, fontSize: 12 }}>⋮⋮</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
              gap: 6, marginTop: 10 }}>
              <div style={{ border: `1px solid ${BRU.ink}`, padding: '6px 8px' }}>
                <div style={{ fontSize: 8, letterSpacing: 1.2, fontWeight: 700, color: BRU.muted }}>WEEKS</div>
                <BruDisplay size={20}>{ph.wks}</BruDisplay>
              </div>
              <div style={{ border: `1px solid ${BRU.ink}`, padding: '6px 8px' }}>
                <div style={{ fontSize: 8, letterSpacing: 1.2, fontWeight: 700, color: BRU.muted }}>VOL</div>
                <BruDisplay size={20}>{ph.vol}</BruDisplay>
              </div>
              <div style={{ border: `1px solid ${BRU.ink}`, padding: '6px 8px' }}>
                <div style={{ fontSize: 8, letterSpacing: 1.2, fontWeight: 700, color: BRU.muted }}>INT</div>
                <BruDisplay size={20}>{ph.int}</BruDisplay>
              </div>
            </div>
          </div>
        ))}
      </div>

      <BruSectionHead>Linked routines · 4</BruSectionHead>
      <div style={{ padding: '10px 16px', display: 'flex', gap: 6,
        flexWrap: 'wrap', borderBottom: `2px solid ${BRU.ink}` }}>
        {['Push A', 'Pull A', 'Push B', 'Pull B'].map(r => (
          <BruChip key={r}>{r}</BruChip>
        ))}
      </div>

      <BruButton kind="primary" size="md">Apply changes ▸</BruButton>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruBlockBuilderScreen = BruBlockBuilderScreen;
