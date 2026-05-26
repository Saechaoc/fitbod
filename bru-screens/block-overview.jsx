// Phase 4 · Block Overview · Active mesocycle, current week, deload visual
// Swipe between weeks, see what's coming, get phase-end review.

function BruBlockOverviewScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹" center="Block · Upper Hyp" right="EDIT" />

      {/* Big block card */}
      <div style={{ background: BRU.ink, color: BRU.paper,
        padding: '14px 16px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.7 }}>
          <span>● ACTIVE BLOCK · #03</span>
          <span style={{ color: BRU.signal }}>14 DAYS REMAINING</span>
        </div>
        <BruDisplay size={42} color={BRU.paper} style={{ marginTop: 6 }}>
          Intensification week
        </BruDisplay>
        <div style={{ display: 'flex', gap: 12, marginTop: 10, fontSize: 11,
          letterSpacing: 1.2, fontWeight: 700 }}>
          <span>W3 / 5</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span style={{ color: BRU.signal }}>VOL HOLD</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span>INT 85%</span>
        </div>
      </div>

      {/* Week swipe carousel */}
      <div style={{ borderBottom: `2px solid ${BRU.ink}`, padding: '12px 16px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, fontWeight: 700, letterSpacing: 1.5, marginBottom: 10 }}>
          <span>‹ W2</span><span>WEEK 3 OF 5</span><span>W4 ›</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)',
          gap: 4 }}>
          {[
            { d: 'M', label: 'PUSH A', done: true, pr: true },
            { d: 'T', label: 'REST', rest: true },
            { d: 'W', label: 'PULL A', done: true },
            { d: 'T', label: 'PUSH B', now: true },
            { d: 'F', label: 'REST', rest: true },
            { d: 'S', label: 'PULL B' },
            { d: 'S', label: 'REST', rest: true },
          ].map((d, i) => (
            <div key={i} style={{
              border: `1.5px solid ${BRU.ink}`,
              background: d.now ? BRU.signal : d.done ? BRU.ink : 'transparent',
              color: d.now || d.done ? BRU.paper : (d.rest ? BRU.muted : BRU.ink),
              padding: '6px 2px', textAlign: 'center', position: 'relative',
            }}>
              <div style={{ fontSize: 11, fontWeight: 700 }}>{d.d}</div>
              <div style={{ fontFamily: BRU.display, fontSize: 13, marginTop: 2,
                opacity: d.rest ? 0.5 : 1 }}>{d.label}</div>
              {d.pr && <div style={{ position: 'absolute', top: -6, right: -3,
                background: BRU.signal, color: BRU.paper, fontSize: 7,
                padding: '1px 3px', fontWeight: 700, letterSpacing: 0.5 }}>PR</div>}
              {d.now && <div style={{ marginTop: 3, fontSize: 8, fontWeight: 700,
                letterSpacing: 1 }}>TODAY</div>}
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          marginTop: 10, fontFamily: BRU.mono, fontSize: 10, color: BRU.muted }}>
          <span>2 / 4 SESSIONS DONE</span>
          <span>2 LEFT</span>
        </div>
      </div>

      {/* Phase progression */}
      <BruSectionHead right="WHAT'S NEXT">Phase progression</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { id: 1, name: 'Accumulation', wks: 'W1–W2', kind: 'BUILD VOLUME', done: true, summary: '+18% tonnage · 3 PRs' },
          { id: 2, name: 'Intensification', wks: 'W3', kind: 'BUILD STRENGTH', now: true, summary: 'In progress · 2/4 sessions' },
          { id: 3, name: 'Peak', wks: 'W4', kind: 'PEAK · −20% vol', upcoming: true, summary: 'Top sets only · 2 sessions' },
          { id: 4, name: 'Deload', wks: 'W5', kind: 'RECOVER · −50% vol', deload: true, summary: 'No warm-ups · ~30 min' },
        ].map(ph => (
          <div key={ph.id} style={{
            padding: '11px 16px', borderBottom: `1px solid ${BRU.hair}`,
            background: ph.now ? `${BRU.signal}0F` : 'transparent',
            position: 'relative',
          }}>
            {ph.now && <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0,
              width: 4, background: BRU.signal }} />}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontFamily: BRU.mono, fontSize: 10, color: BRU.muted,
                width: 38 }}>{ph.wks}</span>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{ph.name}</span>
                  {ph.done && <BruChip>DONE</BruChip>}
                  {ph.now && <BruChip fill color={BRU.signal}>NOW</BruChip>}
                  {ph.deload && <BruChip color={BRU.signal}>DELOAD</BruChip>}
                </div>
                <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                  textTransform: 'uppercase', marginTop: 2 }}>{ph.kind}</div>
                <div style={{ fontSize: 11, marginTop: 4, color: BRU.ink }}>{ph.summary}</div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Deload banner */}
      <div style={{
        borderTop: `2px solid ${BRU.ink}`, padding: '12px 16px',
        background: BRU.bg2,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10,
      }}>
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5, color: BRU.signal }}>
            ▲ FATIGUE ADVISORY
          </div>
          <div style={{ fontSize: 11, marginTop: 3, lineHeight: 1.3 }}>
            e1RM dropped 2.1% over 2 sessions. Deload is scheduled W5; advisory only.
          </div>
        </div>
        <BruChip>DISMISS</BruChip>
      </div>

      <BruTabBar active="today" />
    </BruPhone>
  );
}

window.BruBlockOverviewScreen = BruBlockOverviewScreen;
