// Phase 5 · Plateau Detector + Fatigue Advisory

function BruPlateauScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹" center="Plateau · Bench" right="•••" />

      {/* Big signal banner */}
      <div style={{ background: BRU.signal, color: BRU.paper, padding: '16px',
        position: 'relative' }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.5 }}>
          ▲ STALL DETECTED
        </div>
        <BruDisplay size={36} color={BRU.paper} style={{ marginTop: 6 }}>
          e1RM flat 4 sessions
        </BruDisplay>
        <div style={{ marginTop: 8, fontSize: 12, lineHeight: 1.4, opacity: 0.85 }}>
          Bench Press e1RM has moved ± 1.2% across 4 hypertrophy sessions.
          You're under-stimulating, over-fatigued, or both.
        </div>
      </div>

      {/* The trend */}
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, fontWeight: 700, letterSpacing: 1.5 }}>
          <span>e1RM · LAST 8 SESSIONS</span>
          <span style={{ color: BRU.signal }}>± 1.2%</span>
        </div>
        <div style={{ marginTop: 8 }}>
          <BruSpark
            values={[232, 236, 238, 244, 246, 247, 247, 248]}
            w={361} h={70} color={BRU.ink} fill />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          marginTop: 6, fontFamily: BRU.mono, fontSize: 10, color: BRU.muted }}>
          <span>APR 18</span>
          <span style={{ background: BRU.signal, color: BRU.paper, padding: '1px 4px' }}>
            STALL WINDOW →
          </span>
          <span>MAY 22</span>
        </div>
      </div>

      {/* Suggestions */}
      <BruSectionHead right="PICK ONE">Suggested actions</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { id: 1, label: 'Drop intensity', spec: '−10% load · same volume', best: true,
            why: 'Often resolves an RPE-creep stall in 1–2 sessions.' },
          { id: 2, label: 'Add a working set', spec: '+ 1 set · same load',
            why: 'Stress more if recovery is fine. Chest is in MAV.' },
          { id: 3, label: 'Deload this week', spec: '−50% volume · −15% intensity',
            why: 'Heaviest if fatigue is high. Block schedule pushed to W5.' },
          { id: 4, label: 'Swap variation', spec: 'Bench → DB bench',
            why: 'New stimulus often unblocks a stale lift.' },
        ].map(s => (
          <div key={s.id} style={{ padding: '12px 16px',
            borderBottom: `1px solid ${BRU.hair}`,
            background: s.best ? `${BRU.signal}0F` : 'transparent',
            position: 'relative' }}>
            {s.best && <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0,
              width: 4, background: BRU.signal }} />}
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
              <span style={{ fontFamily: BRU.display, fontSize: 22, color: BRU.signal,
                width: 22 }}>{String(s.id).padStart(2, '0')}</span>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, flexWrap: 'wrap' }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{s.label}</span>
                  {s.best && <BruChip fill color={BRU.signal}>RECOMMENDED</BruChip>}
                </div>
                <div style={{ fontFamily: BRU.mono, fontSize: 11, letterSpacing: 0.4,
                  color: BRU.muted, marginTop: 3 }}>{s.spec}</div>
                <div style={{ fontSize: 11, marginTop: 4, color: BRU.ink, lineHeight: 1.4 }}>{s.why}</div>
              </div>
              <BruChip>APPLY</BruChip>
            </div>
          </div>
        ))}
      </div>

      {/* Thresholds setting */}
      <div style={{ borderTop: `2px solid ${BRU.ink}`, padding: '10px 16px',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        background: BRU.bg2 }}>
        <div>
          <div style={{ fontSize: 9, color: BRU.muted, fontWeight: 700, letterSpacing: 1.2 }}>
            STALL THRESHOLD
          </div>
          <BruDisplay size={20}>± 2% · 3 sessions</BruDisplay>
        </div>
        <BruChip>TUNE</BruChip>
      </div>

      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md">Dismiss</BruButton>
        <BruButton kind="signal" size="md">Apply drop ▸</BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruPlateauScreen = BruPlateauScreen;
