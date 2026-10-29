// Variant D · DARK GARAGE
// High-contrast dark · oversized display numerals · amber accent · gym-meter vibe

const DARK = {
  bg: '#0A0908',
  bg2: '#13110F',
  card: '#1A1815',
  ink: '#F4EFE7',
  muted: '#807A6F',
  faint: '#3F3B36',
  amber: '#F5B027',
  amber2: '#FFC857',
  red: '#E63E2A',
  font: '"Geist", "Söhne", "Bricolage Grotesque", system-ui, sans-serif',
  display: '"Bricolage Grotesque", "Geist", system-ui, sans-serif',
  mono: '"JetBrains Mono", "IBM Plex Mono", ui-monospace, monospace',
};

// Big amber arc gauge
function GaugeArc({ value, label, size = 240, stroke = 10 }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const arc = 0.78; // 78% of circle (segment we draw)
  const len = c * arc;
  const dash = len * value;
  const rot = -90 - (arc * 360) / 2;
  return (
    <svg width={size} height={size} style={{ display: 'block' }}>
      <g transform={`rotate(${rot} ${size/2} ${size/2})`}>
        <circle cx={size/2} cy={size/2} r={r} fill="none"
          stroke={DARK.faint} strokeWidth={stroke}
          strokeDasharray={`${len} ${c}`} strokeLinecap="round" />
        <circle cx={size/2} cy={size/2} r={r} fill="none"
          stroke={DARK.amber} strokeWidth={stroke}
          strokeDasharray={`${dash} ${c}`} strokeLinecap="round"
          style={{ transition: 'stroke-dasharray 1s linear', filter: 'drop-shadow(0 0 6px rgba(245,176,39,0.5))' }} />
      </g>
    </svg>
  );
}

function DarkVariant() {
  const S = useSession();
  const { exercise, currentSet, resting, restRemaining, restTotal,
    logSet, skipRest, addRest, completedCount, totalSets } = S;

  return (
    <div style={{
      width: '100%', height: '100%', background: DARK.bg, color: DARK.ink,
      fontFamily: DARK.font, display: 'flex', flexDirection: 'column',
      padding: '54px 0 0', boxSizing: 'border-box', position: 'relative',
      backgroundImage: `radial-gradient(circle at 50% 20%, rgba(245,176,39,0.06), transparent 60%)`,
    }}>
      {/* status */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between',
        padding: '18px 24px 0', fontSize: 15, fontWeight: 600 }}>
        <span>9:41</span>
        <span style={{ color: DARK.amber, fontFamily: DARK.mono, fontSize: 12 }}>● LIVE</span>
      </div>

      {/* Top context */}
      <div style={{ padding: '4px 20px 18px', display: 'flex',
        justifyContent: 'space-between', alignItems: 'baseline' }}>
        <div>
          <div style={{ fontFamily: DARK.mono, fontSize: 10, letterSpacing: 1.5,
            color: DARK.muted, textTransform: 'uppercase' }}>PUSH·A / W3·5</div>
          <div style={{ fontFamily: DARK.display, fontSize: 24, fontWeight: 600,
            marginTop: 2, letterSpacing: -0.5 }}>Bench Press</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontFamily: DARK.mono, fontSize: 10, color: DARK.muted, letterSpacing: 1 }}>ELAPSED</div>
          <div style={{ fontFamily: DARK.mono, fontSize: 18, color: DARK.amber,
            fontVariantNumeric: 'tabular-nums' }}>38:14</div>
        </div>
      </div>

      {/* Big circular display */}
      <div style={{ position: 'relative', display: 'flex', justifyContent: 'center',
        alignItems: 'center', padding: '0 0 8px' }}>
        <GaugeArc value={!resting ? completedCount / totalSets : restRemaining / restTotal}
          size={300} stroke={6} />
        {/* Centered numeric */}
        <div style={{ position: 'absolute', inset: 0, display: 'flex',
          flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          {!resting ? (
            <>
              <div style={{ fontFamily: DARK.mono, fontSize: 11, letterSpacing: 2,
                color: DARK.amber, textTransform: 'uppercase' }}>
                SET {S.setIdx + 1} · {currentSet.intent?.toUpperCase()}
              </div>
              <div style={{ fontFamily: DARK.display, fontSize: 132, fontWeight: 700,
                letterSpacing: -5, lineHeight: 0.9, marginTop: 2,
                fontVariantNumeric: 'tabular-nums',
                textShadow: '0 0 28px rgba(245,176,39,0.25)' }}>
                {currentSet.weight}
              </div>
              <div style={{ fontFamily: DARK.mono, fontSize: 11, color: DARK.muted,
                letterSpacing: 2, marginTop: -2 }}>POUNDS</div>
              <div style={{ marginTop: 14, display: 'flex', gap: 22,
                fontFamily: DARK.mono, fontSize: 12 }}>
                <span style={{ color: DARK.muted, letterSpacing: 1.5 }}>×</span>
                <span style={{ fontFamily: DARK.display, fontSize: 28, fontWeight: 600,
                  lineHeight: 1, color: DARK.ink, fontVariantNumeric: 'tabular-nums' }}>
                  {currentSet.reps}
                </span>
                <span style={{ color: DARK.faint }}>|</span>
                <span style={{ color: DARK.muted, letterSpacing: 1.5 }}>@</span>
                <span style={{ fontFamily: DARK.display, fontSize: 28, fontWeight: 600,
                  lineHeight: 1, color: DARK.amber, fontVariantNumeric: 'tabular-nums' }}>
                  {currentSet.rpe}
                </span>
              </div>
            </>
          ) : (
            <>
              <div style={{ fontFamily: DARK.mono, fontSize: 11, letterSpacing: 2,
                color: DARK.amber, textTransform: 'uppercase' }}>RESTING</div>
              <div style={{ fontFamily: DARK.display, fontSize: 108, fontWeight: 700,
                letterSpacing: -4, lineHeight: 0.9, marginTop: 6,
                fontVariantNumeric: 'tabular-nums',
                textShadow: '0 0 28px rgba(245,176,39,0.35)' }}>
                {fmtSec(restRemaining)}
              </div>
              <div style={{ fontFamily: DARK.mono, fontSize: 11, color: DARK.muted,
                letterSpacing: 2, marginTop: 6 }}>OF {fmtSec(restTotal)}</div>
            </>
          )}
        </div>
      </div>

      {/* Plate viz strip */}
      {!resting && (
        <div style={{ margin: '6px 20px 8px', padding: '12px 14px',
          background: DARK.card, borderRadius: 8,
          border: `1px solid ${DARK.faint}`,
          display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontFamily: DARK.mono, fontSize: 9, color: DARK.muted,
            letterSpacing: 1.5 }}>BAR/45</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 1, flex: 1 }}>
            <div style={{ width: 18, height: 4, background: DARK.muted }} />
            {window.platesFor(currentSet.weight).map((p, i) => {
              const h = 24 + p * 0.35;
              const w = Math.max(5, p * 0.35);
              return (
                <div key={i} style={{
                  width: w, height: h, borderRadius: 1,
                  background: `linear-gradient(180deg, ${DARK.amber} 0%, ${DARK.amber2} 50%, ${DARK.amber} 100%)`,
                  border: `0.5px solid ${DARK.bg}`,
                }} />
              );
            })}
            <div style={{ flex: 1, height: 3, background: DARK.faint }} />
          </div>
          <span style={{ fontFamily: DARK.mono, fontSize: 10, color: DARK.ink,
            fontVariantNumeric: 'tabular-nums' }}>
            ×2&nbsp;{window.platesFor(currentSet.weight).join('·')}
          </span>
        </div>
      )}

      {/* Set list */}
      <div style={{ flex: 1, padding: '6px 20px 6px', minHeight: 0, overflow: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8,
          fontFamily: DARK.mono, fontSize: 9, letterSpacing: 1.5, color: DARK.muted }}>
          <span>SET LIST</span>
          <span>{completedCount}/{totalSets} DONE</span>
        </div>
        <div style={{ display: 'flex', gap: 5 }}>
          {exercise.sets.map((s, i) => {
            const done = s.done;
            const isCur = i === S.setIdx && !resting;
            return (
              <div key={i} style={{
                flex: 1, padding: '8px 4px',
                background: isCur ? `${DARK.amber}1F` : DARK.card,
                border: `1px solid ${isCur ? DARK.amber : (done ? DARK.faint : DARK.faint)}`,
                borderRadius: 6, textAlign: 'center',
                opacity: done ? 0.55 : 1,
              }}>
                <div style={{ fontFamily: DARK.mono, fontSize: 9, color: done ? DARK.muted : (isCur ? DARK.amber : DARK.muted),
                  letterSpacing: 1 }}>
                  {String(i + 1).padStart(2, '0')}
                </div>
                <div style={{ fontFamily: DARK.display, fontSize: 18, fontWeight: 600,
                  fontVariantNumeric: 'tabular-nums', lineHeight: 1.1,
                  color: isCur ? DARK.amber : DARK.ink, marginTop: 2 }}>
                  {s.weight}
                </div>
                <div style={{ fontFamily: DARK.mono, fontSize: 9, color: DARK.muted,
                  marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>
                  ×{s.actualReps ?? s.reps}·{s.actualRpe ?? s.rpe}
                </div>
                {done && <div style={{ fontSize: 11, color: DARK.amber, marginTop: 1 }}>✓</div>}
              </div>
            );
          })}
        </div>
      </div>

      {/* Up next + ctas */}
      <div style={{ padding: '8px 20px 0', display: 'flex', justifyContent: 'space-between',
        fontFamily: DARK.mono, fontSize: 10, letterSpacing: 1, color: DARK.muted }}>
        <span>NEXT · INCLINE DB</span>
        <span>e1RM <span style={{ color: DARK.amber }}>248 ↑4</span></span>
      </div>

      {!resting ? (
        <button onClick={() => logSet()} style={{
          margin: '12px 20px 24px', padding: '17px 0',
          background: DARK.amber, color: DARK.bg, border: 'none', borderRadius: 10,
          fontFamily: DARK.font, fontSize: 16, fontWeight: 700, letterSpacing: 0.5,
          cursor: 'pointer',
          boxShadow: '0 0 24px rgba(245,176,39,0.4), inset 0 1px 0 rgba(255,255,255,0.3)',
        }}>
          LOG SET · START REST
        </button>
      ) : (
        <div style={{ margin: '8px 20px 24px', display: 'flex', gap: 8 }}>
          <button onClick={() => addRest(30)} style={{
            flex: 1, padding: '15px 0',
            background: 'transparent', color: DARK.ink,
            border: `1px solid ${DARK.faint}`, borderRadius: 10,
            fontFamily: DARK.font, fontSize: 14, fontWeight: 600, cursor: 'pointer',
          }}>+30s</button>
          <button onClick={() => skipRest()} style={{
            flex: 2, padding: '15px 0',
            background: DARK.amber, color: DARK.bg, border: 'none', borderRadius: 10,
            fontFamily: DARK.font, fontSize: 14, fontWeight: 700, cursor: 'pointer',
            boxShadow: '0 0 18px rgba(245,176,39,0.35)',
          }}>SKIP REST →</button>
        </div>
      )}
    </div>
  );
}

window.DarkVariant = DarkVariant;
