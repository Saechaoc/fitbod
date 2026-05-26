// Phase 4 · End-of-Block Review · phase-end summary surfaced automatically

function BruBlockReviewScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹" center="Block review" right="EXPORT" />

      {/* Hero — block complete */}
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '16px' }}>
        <div style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>
          BLOCK 03 · COMPLETE · MAY 1 → MAY 28
        </div>
        <BruDisplay size={36} color={BRU.paper} style={{ marginTop: 4, lineHeight: 1, whiteSpace: 'nowrap' }}>
          Upper hypertrophy
        </BruDisplay>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16,
          marginTop: 14, paddingTop: 14, borderTop: `2px solid ${BRU.paper}` }}>
          <div>
            <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 1.2, fontWeight: 700 }}>SESSIONS</div>
            <BruDisplay size={48} color={BRU.paper}>20</BruDisplay>
            <div style={{ fontSize: 9, opacity: 0.6, marginTop: 2 }}>OUT OF 20 · 100%</div>
          </div>
          <div>
            <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 1.2, fontWeight: 700 }}>TONNAGE</div>
            <BruDisplay size={48} color={BRU.signal}>284K</BruDisplay>
            <div style={{ fontSize: 9, opacity: 0.6, marginTop: 2 }}>↑ 23% VS BLOCK 02</div>
          </div>
          <div>
            <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 1.2, fontWeight: 700 }}>PRS</div>
            <BruDisplay size={48} color={BRU.paper}>9</BruDisplay>
            <div style={{ fontSize: 9, opacity: 0.6, marginTop: 2 }}>5 LIFTS · 4 EXERCISES</div>
          </div>
        </div>
      </div>

      {/* e1RM deltas */}
      <BruSectionHead right="↑ 4 LIFTS">e1RM movement</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { name: 'Bench Press', start: 224, end: 248, delta: '+24', pr: true },
          { name: 'Overhead Press', start: 152, end: 165, delta: '+13', pr: true },
          { name: 'Incline DB Press', start: 78, end: 82, delta: '+4' },
          { name: 'Bent-Over Row', start: 195, end: 212, delta: '+17', pr: true },
          { name: 'Cable Fly', start: 32, end: 34, delta: '+2' },
          { name: 'Pull-up (weighted)', start: 35, end: 45, delta: '+10', pr: true },
        ].map((e, i) => {
          const pct = Math.min(1, (e.end - 50) / 250);
          return (
            <div key={i} style={{
              padding: '10px 16px', borderBottom: `1px solid ${BRU.hair}`,
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between',
                alignItems: 'baseline' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 13, fontWeight: 600 }}>{e.name}</span>
                  {e.pr && <BruChip fill color={BRU.signal}>★ PR</BruChip>}
                </div>
                <span style={{ fontFamily: BRU.display, fontSize: 18,
                  fontVariantNumeric: 'tabular-nums' }}>
                  {e.start} → <span style={{ color: BRU.signal }}>{e.end}</span>
                  <span style={{ fontSize: 12, marginLeft: 6, color: BRU.signal }}>{e.delta}</span>
                </span>
              </div>
              <div style={{ marginTop: 6, height: 4, background: BRU.hair, position: 'relative' }}>
                <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0,
                  width: `${pct * 100}%`,
                  background: BRU.ink }} />
                <div style={{ position: 'absolute', left: `${pct * 100}%`, top: -4, bottom: -4,
                  width: 3, background: BRU.signal }} />
              </div>
            </div>
          );
        })}
      </div>

      {/* Recommended next */}
      <div style={{ borderTop: `2px solid ${BRU.ink}`, padding: '12px 16px',
        background: BRU.bg2 }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5, marginBottom: 4 }}>
          RECOMMENDED NEXT BLOCK
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          alignItems: 'baseline' }}>
          <BruDisplay size={26}>Strength · 4 weeks</BruDisplay>
          <span style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2 }}>BASED ON BLOCK 03</span>
        </div>
      </div>

      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md">Plan custom</BruButton>
        <BruButton kind="signal" size="md">Start next ▸</BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruBlockReviewScreen = BruBlockReviewScreen;
