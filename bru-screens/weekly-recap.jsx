// Phase 6 · Weekly Recap · auto-surfaced at the week boundary

function BruWeeklyRecapScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹" center="Week 3 · recap" right="SHARE" />

      {/* Cover */}
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '20px 16px' }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5, opacity: 0.6 }}>
          MAY 15 → MAY 21 · INTENSIFICATION
        </div>
        <BruDisplay size={68} color={BRU.paper} style={{ marginTop: 4, lineHeight: 0.86 }}>
          A strong<br />week.
        </BruDisplay>
        <div style={{ display: 'flex', gap: 6, marginTop: 12, flexWrap: 'wrap' }}>
          <BruChip color={BRU.paper} fill style={{ background: BRU.signal, borderColor: BRU.signal }}>
            ★ 3 PRs
          </BruChip>
          <BruChip color={BRU.paper} style={{ borderColor: BRU.paper }}>
            4 / 4 sessions
          </BruChip>
          <BruChip color={BRU.paper} style={{ borderColor: BRU.paper }}>
            21,510 lb
          </BruChip>
        </div>
      </div>

      {/* Headline metrics 2×2 */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr',
        borderBottom: `2px solid ${BRU.ink}` }}>
        {[
          { l: 'TONNAGE', v: '21.5K', sub: '↑ 6% vs W2', accent: true },
          { l: 'WORKING SETS', v: '85', sub: '↑ 12 vs W2' },
          { l: 'AVG RPE', v: '8.2', sub: 'TARGET 8.5' },
          { l: 'MUSCLES HIT', v: '8 / 11', sub: '3 UNDER MEV' },
        ].map((m, i) => (
          <div key={i} style={{
            padding: '14px 16px',
            borderRight: i % 2 === 0 ? `1px solid ${BRU.ink}` : 'none',
            borderBottom: i < 2 ? `1px solid ${BRU.ink}` : 'none',
          }}>
            <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5, fontWeight: 700 }}>
              {m.l}
            </div>
            <BruDisplay size={38} color={m.accent ? BRU.signal : BRU.ink}>{m.v}</BruDisplay>
            <div style={{ fontSize: 10, color: BRU.muted, marginTop: 2, letterSpacing: 0.5 }}>
              {m.sub}
            </div>
          </div>
        ))}
      </div>

      {/* PRs */}
      <BruSectionHead right="3">Records broken</BruSectionHead>
      <div style={{ borderBottom: `2px solid ${BRU.ink}` }}>
        {[
          { name: 'Bench Press', kind: 'e1RM PR', delta: '+4 lb', val: '248', signal: true },
          { name: 'Bench Press', kind: 'Volume PR', delta: '+200 lb', val: '4,610' },
          { name: 'Bent-Over Row', kind: 'Top reps PR', delta: '+1 rep', val: '8 @ 215' },
        ].map((p, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '11px 16px', borderBottom: i < 2 ? `1px solid ${BRU.hair}` : 'none',
          }}>
            <div style={{ fontFamily: BRU.display, fontSize: 26, color: BRU.signal,
              width: 24 }}>★</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 600 }}>{p.name}</div>
              <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 1, marginTop: 2 }}>
                {p.kind}
              </div>
            </div>
            <BruDisplay size={22} color={p.signal ? BRU.signal : BRU.ink}>
              {p.val}
            </BruDisplay>
          </div>
        ))}
      </div>

      {/* Under-trained */}
      <BruSectionHead right="2">Under-trained</BruSectionHead>
      <div style={{ padding: '10px 16px 0' }}>
        {['HAMSTRINGS · 0 sets', 'QUADS · 6 sets (MEV 8)', 'CALVES · 4 sets (MEV 8)'].map((s, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10,
            padding: '8px 0', borderBottom: i < 2 ? `1px solid ${BRU.hair}` : 'none' }}>
            <div style={{ width: 6, height: 6, background: BRU.amber }} />
            <span style={{ fontSize: 12, fontWeight: 600, letterSpacing: 0.5 }}>{s}</span>
          </div>
        ))}
      </div>

      {/* Quote/note */}
      <div style={{ flex: 1, padding: '16px', display: 'flex',
        alignItems: 'flex-end' }}>
        <div style={{ fontSize: 11, color: BRU.muted, lineHeight: 1.5, fontStyle: 'italic' }}>
          "Mon · Bench bench felt hot from the warmup. Top set at 205 — 0.5 in reserve.
          Earned the weight bump."
          <div style={{ fontSize: 9, marginTop: 6, fontStyle: 'normal', letterSpacing: 1 }}>
            — SESSION NOTE · WED MAY 17
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md">All recaps</BruButton>
        <BruButton kind="primary" size="md">Start W4 ▸</BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruWeeklyRecapScreen = BruWeeklyRecapScreen;
