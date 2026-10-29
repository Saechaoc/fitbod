// Variant B · BRUTALIST
// Hard edges · condensed display · black/white with single signal color · uppercase

const BRU = {
  bg: '#F0EDE5',     // raw paper
  ink: '#0A0A0A',
  ink2: '#1C1C1A',
  rule: '#0A0A0A',
  paper: '#FFFFFF',
  signal: '#FF4D2E',  // signal red
  green: '#1A5F3F',
  font: '"Space Grotesk", "Geist", system-ui, sans-serif',
  display: '"Bebas Neue", "Oswald", "Archivo Narrow", "Space Grotesk", sans-serif',
};

function BruBox({ children, style, fill = false }) {
  return (
    <div style={{
      border: `2px solid ${BRU.ink}`,
      background: fill ? BRU.ink : 'transparent',
      color: fill ? BRU.paper : BRU.ink,
      ...style,
    }}>{children}</div>
  );
}

function BrutalistVariant() {
  const S = useSession();
  const { exercise, currentSet, resting, restRemaining, restTotal,
    logSet, skipRest, addRest, totalSets } = S;

  const kindUpper = {
    warmup: 'W/UP', working: 'WORK', top: 'TOP', backoff: 'BACK', cluster: 'CLUS',
  };

  return (
    <div style={{
      width: '100%', height: '100%', background: BRU.bg, color: BRU.ink,
      fontFamily: BRU.font, display: 'flex', flexDirection: 'column',
      padding: '54px 0 0', boxSizing: 'border-box',
      letterSpacing: 0.2,
    }}>
      {/* status */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between',
        padding: '18px 24px 0', fontSize: 13, fontWeight: 700 }}>
        <span>9:41</span>
        <span>● REC</span>
      </div>

      {/* Header bar */}
      <div style={{ borderTop: `2px solid ${BRU.ink}`, borderBottom: `2px solid ${BRU.ink}`,
        padding: '8px 16px', display: 'flex', justifyContent: 'space-between',
        fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1.2,
        whiteSpace: 'nowrap' }}>
        <span>Push / A</span>
        <span>· 38:14 ·</span>
        <span>W3 of 5</span>
      </div>

      {/* Exercise name slab */}
      <div style={{ padding: '20px 16px 12px' }}>
        <div style={{ fontFamily: BRU.display, fontSize: 56, fontWeight: 400,
          lineHeight: 0.86, letterSpacing: 0.5, textTransform: 'uppercase' }}>
          Bench<br />Press
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          marginTop: 10, fontSize: 11, textTransform: 'uppercase', letterSpacing: 1.5, fontWeight: 700 }}>
          <span>Ex 01 / 05</span>
          <span style={{ color: BRU.signal }}>● TOP SET</span>
        </div>
      </div>

      {/* HERO panel — black slab on hero state, inverted on rest */}
      {!resting ? (
        <div style={{
          margin: '0 16px', background: BRU.ink, color: BRU.paper,
          padding: '20px 18px 18px', position: 'relative',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between',
            fontSize: 10, letterSpacing: 1.5, fontWeight: 700, textTransform: 'uppercase',
            whiteSpace: 'nowrap' }}>
            <span>SET {String(S.setIdx + 1).padStart(2,'0')} / {String(totalSets).padStart(2,'0')}</span>
            <span style={{ color: BRU.signal }}>{kindUpper[currentSet.kind]}</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 0, marginTop: 14 }}>
            <span style={{ fontFamily: BRU.display, fontSize: 168, lineHeight: 0.78,
              letterSpacing: -2, fontVariantNumeric: 'tabular-nums', fontWeight: 400 }}>
              {currentSet.weight}
            </span>
            <span style={{ fontFamily: BRU.display, fontSize: 28, marginBottom: 18,
              marginLeft: 6, letterSpacing: 1, opacity: 0.6 }}>LB</span>
          </div>

          <div style={{ display: 'flex', borderTop: `2px solid ${BRU.paper}`, marginTop: 8 }}>
            <div style={{ flex: 1, padding: '10px 0', borderRight: `2px solid ${BRU.paper}` }}>
              <div style={{ fontSize: 9, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>REPS</div>
              <div style={{ fontFamily: BRU.display, fontSize: 36, lineHeight: 1,
                fontVariantNumeric: 'tabular-nums' }}>×{currentSet.reps}</div>
            </div>
            <div style={{ flex: 1, padding: '10px 0 10px 12px' }}>
              <div style={{ fontSize: 9, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>RPE</div>
              <div style={{ fontFamily: BRU.display, fontSize: 36, lineHeight: 1,
                color: BRU.signal, fontVariantNumeric: 'tabular-nums' }}>@{currentSet.rpe}</div>
            </div>
          </div>
        </div>
      ) : (
        <div style={{
          margin: '0 16px', background: BRU.signal, color: BRU.paper,
          padding: '16px 18px',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between',
            fontSize: 10, letterSpacing: 1.5, fontWeight: 700, textTransform: 'uppercase' }}>
            <span>REST</span><span>OF {fmtSec(restTotal)}</span>
          </div>
          <div style={{ fontFamily: BRU.display, fontSize: 152, lineHeight: 0.84,
            fontVariantNumeric: 'tabular-nums', marginTop: 6 }}>
            {fmtSec(restRemaining)}
          </div>
          {/* tick bars */}
          <div style={{ display: 'flex', gap: 2, marginTop: 6, height: 14 }}>
            {Array.from({ length: 40 }).map((_, i) => {
              const filled = i / 40 < restRemaining / restTotal;
              return <div key={i} style={{ flex: 1, background: filled ? BRU.paper : 'rgba(255,255,255,0.25)' }} />;
            })}
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button onClick={() => addRest(30)} style={{
              flex: 1, padding: '12px 0', border: `2px solid ${BRU.paper}`,
              background: 'transparent', color: BRU.paper,
              fontFamily: BRU.font, fontSize: 11, fontWeight: 700, letterSpacing: 1.5,
              textTransform: 'uppercase', cursor: 'pointer',
            }}>+30s</button>
            <button onClick={() => skipRest()} style={{
              flex: 2, padding: '12px 0', border: 'none',
              background: BRU.paper, color: BRU.ink,
              fontFamily: BRU.font, fontSize: 11, fontWeight: 700, letterSpacing: 1.5,
              textTransform: 'uppercase', cursor: 'pointer',
            }}>SKIP →</button>
          </div>
        </div>
      )}

      {/* SET LIST · brutalist rows */}
      <div style={{ flex: 1, padding: '20px 16px 12px', minHeight: 0, overflow: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, letterSpacing: 1.5, fontWeight: 700, marginBottom: 10 }}>
          <span>SET LIST</span>
          <span style={{ color: 'rgba(0,0,0,0.5)' }}>{S.completedCount} OF {totalSets} ✓</span>
        </div>
        {exercise.sets.map((s, i) => {
          const isCur = i === S.setIdx && !resting;
          const done = s.done;
          return (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '34px 1fr 60px 44px 36px',
              alignItems: 'center', gap: 4,
              padding: '6px 8px',
              borderTop: i === 0 ? `2px solid ${BRU.ink}` : `1px solid ${BRU.ink}`,
              borderBottom: i === exercise.sets.length - 1 ? `2px solid ${BRU.ink}` : 'none',
              background: isCur ? BRU.ink : done ? 'transparent' : 'transparent',
              color: isCur ? BRU.paper : done ? 'rgba(10,10,10,0.45)' : BRU.ink,
              textDecoration: done ? 'line-through' : 'none',
              textDecorationColor: 'rgba(10,10,10,0.3)',
              textDecorationThickness: '1px',
            }}>
              <span style={{ fontFamily: BRU.display, fontSize: 22, lineHeight: 1 }}>
                {String(i + 1).padStart(2, '0')}
              </span>
              <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.2 }}>
                {kindUpper[s.kind]}
              </span>
              <span style={{ fontFamily: BRU.display, fontSize: 22, textAlign: 'right',
                fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>{s.weight}</span>
              <span style={{ fontFamily: BRU.display, fontSize: 20, textAlign: 'right',
                fontVariantNumeric: 'tabular-nums', lineHeight: 1,
                opacity: done ? 0.7 : 1 }}>×{s.actualReps ?? s.reps}</span>
              <span style={{ fontFamily: BRU.display, fontSize: 20, textAlign: 'right',
                fontVariantNumeric: 'tabular-nums', lineHeight: 1,
                color: isCur ? BRU.signal : (done ? 'inherit' : BRU.signal) }}>@{s.actualRpe ?? s.rpe}</span>
            </div>
          );
        })}
      </div>

      {/* Bottom: log set CTA — massive */}
      {!resting && (
        <button onClick={() => logSet()} style={{
          margin: '8px 16px 24px',
          background: BRU.signal, color: BRU.paper, border: 'none',
          padding: '20px 0', cursor: 'pointer',
          fontFamily: BRU.display, fontSize: 32, letterSpacing: 2,
          textTransform: 'uppercase', lineHeight: 1,
        }}>
          LOG SET ▸
        </button>
      )}
      {resting && (
        <div style={{ margin: '8px 16px 24px', display: 'flex', justifyContent: 'space-between',
          fontSize: 10, fontWeight: 700, letterSpacing: 1.5,
          padding: '14px 16px', border: `2px solid ${BRU.ink}` }}>
          <span>RESTING · AUTO RESUME</span>
          <span style={{ fontFamily: BRU.display, fontSize: 14 }}>{fmtSec(restRemaining)}</span>
        </div>
      )}
    </div>
  );
}

window.BrutalistVariant = BrutalistVariant;
