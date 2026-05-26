// Phase 5 · Weekly Volume · MEV / MAV / MRV bars with verb labels per muscle

function BruVolumeScreen() {
  // Per-muscle weekly volume in stimulus-weighted sets
  const muscles = [
    { name: 'CHEST',      current: 16, mev: 8,  mav: 18, mrv: 22, verb: 'ADD A SET',         color: BRU.green },
    { name: 'TRICEPS',    current: 19, mev: 6,  mav: 14, mrv: 20, verb: 'NEAR MRV — DELOAD', color: BRU.signal, alarm: true },
    { name: 'FRONT DELT', current: 12, mev: 6,  mav: 16, mrv: 22, verb: 'HOLD',              color: BRU.ink },
    { name: 'LATS',       current: 14, mev: 10, mav: 18, mrv: 24, verb: 'HOLD',              color: BRU.ink },
    { name: 'BICEPS',     current: 8,  mev: 8,  mav: 16, mrv: 22, verb: 'ADD A SET',         color: BRU.green },
    { name: 'QUADS',      current: 6,  mev: 8,  mav: 16, mrv: 22, verb: 'UNDER MEV',         color: BRU.amber, warn: true },
    { name: 'HAMSTRINGS', current: 0,  mev: 6,  mav: 14, mrv: 20, verb: 'NOT TRAINED',       color: BRU.muted, off: true },
    { name: 'GLUTES',     current: 10, mev: 6,  mav: 14, mrv: 18, verb: 'HOLD',              color: BRU.ink },
  ];
  const SCALE = 25; // max sets on the axis

  return (
    <BruPhone>
      <BruHeader left="‹" center="Volume · W3" right="•••" />

      {/* Summary slab */}
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '14px 16px',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>
            WORKING SETS · 7 DAYS
          </div>
          <BruDisplay size={56} color={BRU.paper}>85</BruDisplay>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>VS LAST WK</div>
          <BruDisplay size={32} color={BRU.signal}>+12</BruDisplay>
          <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 1 }}>STIMULUS-WEIGHTED</div>
        </div>
      </div>

      {/* Legend */}
      <div style={{ display: 'flex', padding: '8px 16px', borderBottom: `2px solid ${BRU.ink}`,
        fontSize: 9, fontWeight: 700, letterSpacing: 1.2, gap: 16 }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <div style={{ width: 12, height: 8, background: BRU.bg2, border: `1px solid ${BRU.ink}` }} />
          UNDER MEV
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <div style={{ width: 12, height: 8, background: BRU.ink }} />
          MEV → MAV
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <div style={{ width: 12, height: 8, background: BRU.signal }} />
          MRV
        </span>
      </div>

      {/* Bars */}
      <div style={{ flex: 1, overflow: 'auto' }}>
        {muscles.map((m, i) => {
          const mevX = (m.mev / SCALE) * 100;
          const mavX = (m.mav / SCALE) * 100;
          const mrvX = (m.mrv / SCALE) * 100;
          const curX = Math.min(100, (m.current / SCALE) * 100);
          const fillColor = m.alarm ? BRU.signal : m.warn ? BRU.amber : m.off ? BRU.faint : BRU.ink;
          return (
            <div key={i} style={{ padding: '11px 16px', borderBottom: `1px solid ${BRU.hair}` }}>
              <div style={{ display: 'flex', justifyContent: 'space-between',
                alignItems: 'baseline' }}>
                <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2 }}>
                  {m.name}
                </span>
                <span style={{ display: 'flex', gap: 10, alignItems: 'baseline' }}>
                  <span style={{ fontFamily: BRU.display, fontSize: 24,
                    color: fillColor, fontVariantNumeric: 'tabular-nums' }}>
                    {m.current}
                  </span>
                  <span style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1 }}>
                    SETS
                  </span>
                </span>
              </div>
              {/* Bar */}
              <div style={{
                marginTop: 6, height: 16, position: 'relative',
                border: `1.5px solid ${BRU.ink}`, background: BRU.bg2,
              }}>
                {/* current fill */}
                <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0,
                  width: `${curX}%`,
                  background: fillColor,
                  borderRight: `2px solid ${BRU.ink}`,
                }} />
                {/* MEV mark */}
                <div style={{ position: 'absolute', left: `${mevX}%`, top: -3, bottom: -3,
                  width: 1, background: BRU.ink }}>
                  <div style={{ position: 'absolute', top: -10, left: -10,
                    fontFamily: BRU.mono, fontSize: 8, color: BRU.muted,
                    letterSpacing: 0.5 }}>MEV</div>
                </div>
                {/* MAV mark */}
                <div style={{ position: 'absolute', left: `${mavX}%`, top: -3, bottom: -3,
                  width: 1, background: BRU.ink }}>
                  <div style={{ position: 'absolute', top: -10, left: -10,
                    fontFamily: BRU.mono, fontSize: 8, color: BRU.muted,
                    letterSpacing: 0.5 }}>MAV</div>
                </div>
                {/* MRV mark */}
                <div style={{ position: 'absolute', left: `${mrvX}%`, top: -3, bottom: -3,
                  width: 1, background: BRU.signal }}>
                  <div style={{ position: 'absolute', top: -10, left: -10,
                    fontFamily: BRU.mono, fontSize: 8, color: BRU.signal,
                    letterSpacing: 0.5 }}>MRV</div>
                </div>
              </div>
              {/* Verb label */}
              <div style={{ marginTop: 8, display: 'flex', justifyContent: 'space-between',
                alignItems: 'center' }}>
                <BruChip color={fillColor} fill={m.alarm || m.warn}>
                  {m.verb}
                </BruChip>
                <span style={{ fontFamily: BRU.mono, fontSize: 9, color: BRU.muted,
                  letterSpacing: 0.5 }}>
                  MEV {m.mev} · MAV {m.mav} · MRV {m.mrv}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      <BruTabBar active="progress" />
    </BruPhone>
  );
}

window.BruVolumeScreen = BruVolumeScreen;
