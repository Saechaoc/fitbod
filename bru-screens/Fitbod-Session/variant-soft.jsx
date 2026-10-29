// Variant C · SOFT MODERN iOS
// Rounded cards · system blue · generous padding · native feel

const SOFT = {
  bg: '#F2F2F7',       // iOS grouped bg
  card: '#FFFFFF',
  ink: '#000000',
  ink2: '#1C1C1E',
  secondary: 'rgba(60,60,67,0.6)',
  tertiary: 'rgba(60,60,67,0.3)',
  sep: 'rgba(60,60,67,0.12)',
  accent: '#007AFF',
  accent2: '#5856D6',
  green: '#34C759',
  orange: '#FF9500',
  red: '#FF3B30',
  font: '-apple-system, "SF Pro Text", system-ui, sans-serif',
  display: '-apple-system, "SF Pro Display", system-ui, sans-serif',
};

function SoftCard({ children, style }) {
  return (
    <div style={{
      background: SOFT.card, borderRadius: 16,
      ...style,
    }}>{children}</div>
  );
}

function SoftVariant() {
  const S = useSession();
  const { exercise, currentSet, resting, restRemaining, restTotal,
    logSet, skipRest, addRest, completedCount, totalSets } = S;

  const intentColor = currentSet.kind === 'top' ? SOFT.red :
                      currentSet.kind === 'backoff' ? SOFT.orange :
                      currentSet.kind === 'warmup' ? SOFT.secondary : SOFT.accent;
  const intentLabel = {
    warmup: 'Warm-up', working: 'Working', top: 'Top set', backoff: 'Back-off', cluster: 'Cluster',
  }[currentSet.kind] || 'Working';

  return (
    <div style={{
      width: '100%', height: '100%', background: SOFT.bg, color: SOFT.ink,
      fontFamily: SOFT.font, display: 'flex', flexDirection: 'column',
      padding: '54px 0 0', boxSizing: 'border-box', position: 'relative',
      WebkitFontSmoothing: 'antialiased',
    }}>
      {/* Status bar */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between',
        padding: '17px 28px 0', fontSize: 16, fontWeight: 600 }}>
        <span>9:41</span><span>● 38:14</span>
      </div>

      {/* Nav bar */}
      <div style={{ padding: '4px 16px 12px', display: 'flex',
        justifyContent: 'space-between', alignItems: 'center' }}>
        <button style={{ background: 'none', border: 'none', color: SOFT.accent,
          fontSize: 17, padding: 0, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}>
          <svg width="13" height="20" viewBox="0 0 13 20"><path d="M11 2L3 10l8 8" fill="none" stroke={SOFT.accent} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
          Push A
        </button>
        <div style={{ display: 'flex', gap: 18, alignItems: 'center' }}>
          <span style={{ fontSize: 13, color: SOFT.secondary, fontVariantNumeric: 'tabular-nums' }}>
            {completedCount}/{totalSets} sets · 38:14
          </span>
        </div>
      </div>

      {/* Exercise large title */}
      <div style={{ padding: '0 16px 16px' }}>
        <div style={{ fontFamily: SOFT.display, fontSize: 28, fontWeight: 700,
          letterSpacing: 0.36, lineHeight: 1.1 }}>
          Bench Press
        </div>
        <div style={{ fontSize: 13, color: SOFT.secondary, marginTop: 2 }}>
          Chest · Barbell · Exercise 1 of 5
        </div>
      </div>

      {/* Hero card — set or rest */}
      <div style={{ padding: '0 16px' }}>
        {!resting ? (
          <SoftCard style={{ padding: '18px 20px 16px', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{
                fontSize: 12, fontWeight: 600,
                padding: '4px 10px', borderRadius: 999,
                background: `${intentColor}1A`, color: intentColor,
              }}>{intentLabel}</span>
              <span style={{ fontSize: 13, color: SOFT.secondary, fontVariantNumeric: 'tabular-nums' }}>
                Set {S.setIdx + 1} of {totalSets}
              </span>
            </div>

            {/* Weight hero */}
            <div style={{ textAlign: 'center', marginTop: 14 }}>
              <div style={{ fontFamily: SOFT.display, fontSize: 84, fontWeight: 700,
                letterSpacing: -3, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>
                {currentSet.weight}
                <span style={{ fontSize: 22, color: SOFT.secondary, fontWeight: 500,
                  letterSpacing: 0, marginLeft: 6 }}>lb</span>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 8,
              marginTop: 14, paddingTop: 14, borderTop: `0.5px solid ${SOFT.sep}` }}>
              <div style={{ flex: 1, textAlign: 'center' }}>
                <div style={{ fontFamily: SOFT.display, fontSize: 28, fontWeight: 600,
                  fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>
                  ×{currentSet.reps}
                </div>
                <div style={{ fontSize: 10, color: SOFT.secondary, marginTop: 4,
                  fontWeight: 600, letterSpacing: 0.5 }}>REPS</div>
              </div>
              <div style={{ width: 0.5, background: SOFT.sep }} />
              <div style={{ flex: 1, textAlign: 'center' }}>
                <div style={{ fontFamily: SOFT.display, fontSize: 28, fontWeight: 600,
                  color: intentColor, fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>
                  @{currentSet.rpe}
                </div>
                <div style={{ fontSize: 10, color: SOFT.secondary, marginTop: 4,
                  fontWeight: 600, letterSpacing: 0.5 }}>RPE</div>
              </div>
              <div style={{ width: 0.5, background: SOFT.sep }} />
              <div style={{ flex: 1, textAlign: 'center' }}>
                <div style={{ fontFamily: SOFT.display, fontSize: 28, fontWeight: 600,
                  fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>
                  3:00
                </div>
                <div style={{ fontSize: 10, color: SOFT.secondary, marginTop: 4,
                  fontWeight: 600, letterSpacing: 0.5 }}>REST</div>
              </div>
            </div>

            {/* Plate row */}
            <div style={{
              marginTop: 12, padding: '8px 12px', borderRadius: 10,
              background: SOFT.bg,
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <span style={{ fontSize: 10, color: SOFT.secondary, fontWeight: 600, letterSpacing: 0.5 }}>BAR</span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 1, flex: 1 }}>
                <div style={{ width: 14, height: 5, background: SOFT.secondary, borderRadius: 1 }} />
                {window.platesFor(currentSet.weight).map((p, i) => {
                  const h = 18 + p * 0.3;
                  const w = Math.max(5, p * 0.32);
                  const isHeavy = p >= 25;
                  return (
                    <div key={i} style={{
                      width: w, height: h, borderRadius: 2,
                      background: isHeavy ? SOFT.ink2 : SOFT.secondary,
                    }} />
                  );
                })}
                <div style={{ flex: 1, height: 3, background: SOFT.tertiary, borderRadius: 1 }} />
              </div>
              <span style={{ fontSize: 11, color: SOFT.ink, fontWeight: 600,
                fontVariantNumeric: 'tabular-nums' }}>
                {window.platesFor(currentSet.weight).join('·')}
              </span>
            </div>
          </SoftCard>
        ) : (
          <SoftCard style={{ padding: 22, background: SOFT.ink2, color: '#fff' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12, fontWeight: 600,
                padding: '4px 10px', borderRadius: 999,
                background: 'rgba(255,255,255,0.15)' }}>Rest</span>
              <span style={{ fontSize: 13, opacity: 0.7, fontVariantNumeric: 'tabular-nums' }}>
                / {fmtSec(restTotal)}
              </span>
            </div>
            <div style={{ fontFamily: SOFT.display, fontSize: 96, fontWeight: 700,
              letterSpacing: -3, fontVariantNumeric: 'tabular-nums',
              textAlign: 'center', marginTop: 14, lineHeight: 1 }}>
              {fmtSec(restRemaining)}
            </div>
            {/* circular-style progress as a thin bar */}
            <div style={{ height: 6, background: 'rgba(255,255,255,0.15)', borderRadius: 3,
              marginTop: 14, overflow: 'hidden' }}>
              <div style={{ height: '100%', width: `${(restRemaining/restTotal)*100}%`,
                background: SOFT.accent, transition: 'width 1s linear' }} />
            </div>
            <div style={{ fontSize: 13, opacity: 0.7, textAlign: 'center', marginTop: 14 }}>
              Up next · <span style={{ color: '#fff', fontWeight: 600 }}>
                {currentSet.weight} × {currentSet.reps} @ RPE {currentSet.rpe}</span>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button onClick={() => addRest(30)} style={{
                flex: 1, padding: '12px 0',
                background: 'rgba(255,255,255,0.15)', color: '#fff',
                border: 'none', borderRadius: 12, fontSize: 15, fontWeight: 600, cursor: 'pointer',
                fontFamily: SOFT.font,
              }}>+30 s</button>
              <button onClick={() => skipRest()} style={{
                flex: 1, padding: '12px 0',
                background: SOFT.accent, color: '#fff',
                border: 'none', borderRadius: 12, fontSize: 15, fontWeight: 600, cursor: 'pointer',
                fontFamily: SOFT.font,
              }}>Skip rest</button>
            </div>
          </SoftCard>
        )}
      </div>

      {/* Set list card */}
      <div style={{ padding: '14px 16px 0', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ fontSize: 13, color: SOFT.secondary, fontWeight: 600,
          textTransform: 'uppercase', letterSpacing: 0.5, padding: '0 4px 6px' }}>
          Sets
        </div>
        <SoftCard style={{ overflow: 'hidden' }}>
          {exercise.sets.map((s, i) => {
            const isCur = i === S.setIdx && !resting;
            const done = s.done;
            return (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', minHeight: 44,
                padding: '0 16px',
                borderBottom: i < exercise.sets.length - 1 ? `0.5px solid ${SOFT.sep}` : 'none',
                background: isCur ? `${SOFT.accent}10` : 'transparent',
              }}>
                <div style={{
                  width: 24, height: 24, borderRadius: 12, marginRight: 12,
                  background: done ? SOFT.green : isCur ? SOFT.accent : 'transparent',
                  border: done || isCur ? 'none' : `1.5px solid ${SOFT.tertiary}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: '#fff', fontSize: 11, fontWeight: 700, fontVariantNumeric: 'tabular-nums',
                }}>
                  {done ? '✓' : i + 1}
                </div>
                <span style={{ fontSize: 14, color: SOFT.ink, fontWeight: isCur ? 600 : 400, flex: 1 }}>
                  {{ warmup:'Warm-up', working:'Working', top:'Top set', backoff:'Back-off', cluster:'Cluster'}[s.kind]}
                </span>
                <span style={{ fontSize: 15, color: done ? SOFT.secondary : SOFT.ink,
                  fontVariantNumeric: 'tabular-nums', fontWeight: 500,
                  textDecoration: done ? 'line-through' : 'none' }}>
                  {s.weight} × {s.actualReps ?? s.reps}
                </span>
                <span style={{
                  fontSize: 12, color: SOFT.secondary, marginLeft: 10, minWidth: 38, textAlign: 'right',
                  fontVariantNumeric: 'tabular-nums',
                }}>@{s.actualRpe ?? s.rpe}</span>
              </div>
            );
          })}
        </SoftCard>

        <div style={{ display: 'flex', gap: 10, padding: '12px 4px 0',
          fontSize: 12, color: SOFT.secondary, justifyContent: 'space-between' }}>
          <span>Last · 195×8 @ 8.5</span>
          <span style={{ color: SOFT.green, fontWeight: 600 }}>e1RM 248 ↑4</span>
        </div>
      </div>

      {/* CTA */}
      {!resting ? (
        <button onClick={() => logSet()} style={{
          margin: '12px 16px 24px',
          background: SOFT.accent, color: '#fff', border: 'none',
          borderRadius: 14, padding: '15px 0',
          fontSize: 17, fontWeight: 600, cursor: 'pointer', fontFamily: SOFT.font,
          boxShadow: '0 6px 16px rgba(0,122,255,0.25)',
        }}>
          Log set
        </button>
      ) : (
        <div style={{ margin: '12px 16px 24px', padding: '14px 0',
          textAlign: 'center', fontSize: 13, color: SOFT.secondary }}>
          Resting · auto-resume in {fmtSec(restRemaining)}
        </div>
      )}
    </div>
  );
}

window.SoftVariant = SoftVariant;
