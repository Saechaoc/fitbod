// Variant A · DATA TERMINAL
// Mono everywhere · hairline borders · tabular numbers · Bloomberg-for-lifting

const TERM = {
  bg: '#FAFAF7',
  ink: '#0F1311',
  muted: '#6B716D',
  faint: '#A8ADA8',
  rule: '#16191780',
  ruleSoft: '#16191720',
  accent: '#0F1311',
  signal: '#D6402C',     // PR/alert
  good: '#2E7D5B',       // done
  font: '"JetBrains Mono", "IBM Plex Mono", ui-monospace, monospace',
  display: '"Geist", "Inter", -apple-system, sans-serif',
};

function TermRule({ dashed, label, style }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 8,
      borderTop: `0.5px ${dashed ? 'dashed' : 'solid'} ${TERM.rule}`,
      ...style,
    }}>
      {label && (
        <span style={{
          fontFamily: TERM.font, fontSize: 9, letterSpacing: 0.6,
          color: TERM.muted, textTransform: 'uppercase',
          background: TERM.bg, padding: '0 6px',
          transform: 'translateY(-50%)', display: 'inline-block',
        }}>{label}</span>
      )}
    </div>
  );
}

function TermKV({ k, v, mono = true, color = TERM.ink, size = 10 }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      <span style={{ fontFamily: TERM.font, fontSize: 9, letterSpacing: 0.6,
        color: TERM.muted, textTransform: 'uppercase' }}>{k}</span>
      <span style={{
        fontFamily: mono ? TERM.font : TERM.display,
        fontSize: size, color, fontVariantNumeric: 'tabular-nums', lineHeight: 1,
      }}>{v}</span>
    </div>
  );
}

function TermSpark({ values, w = 60, h = 18, color = TERM.ink }) {
  const min = Math.min(...values), max = Math.max(...values);
  const pad = (max - min) * 0.15 || 1;
  const lo = min - pad, hi = max + pad;
  const pts = values.map((v, i) => {
    const x = (i / (values.length - 1)) * w;
    const y = h - ((v - lo) / (hi - lo)) * h;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');
  return (
    <svg width={w} height={h} style={{ display: 'block' }}>
      <polyline points={pts} fill="none" stroke={color} strokeWidth="1" />
      {values.map((v, i) => {
        const x = (i / (values.length - 1)) * w;
        const y = h - ((v - lo) / (hi - lo)) * h;
        return <circle key={i} cx={x} cy={y} r="1.2" fill={color} />;
      })}
    </svg>
  );
}

function fmtSec(s) {
  const m = Math.floor(s / 60), r = s % 60;
  return `${String(m).padStart(2,'0')}:${String(r).padStart(2,'0')}`;
}

function TerminalVariant() {
  const S = useSession();
  const { exercise, currentSet, resting, restRemaining, restTotal,
    logSet, skipRest, addRest, completedCount, totalSets } = S;
  const kindLabel = {
    warmup: 'WU', working: 'WORK', top: 'TOP', backoff: 'BACK', cluster: 'CLUS',
  };

  return (
    <div style={{
      width: '100%', height: '100%', background: TERM.bg, color: TERM.ink,
      fontFamily: TERM.font, display: 'flex', flexDirection: 'column',
      padding: '52px 0 0', boxSizing: 'border-box', position: 'relative',
    }}>
      {/* status bar (custom mono) */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between',
        padding: '16px 28px 0', fontSize: 11, color: TERM.ink }}>
        <span style={{ fontWeight: 600 }}>9:41</span>
        <span style={{ fontSize: 9, color: TERM.muted, letterSpacing: 0.8 }}>FITLOG · v0.3.1</span>
      </div>

      {/* Top context bar */}
      <div style={{ padding: '8px 16px 10px', display: 'flex',
        justifyContent: 'space-between', alignItems: 'baseline',
        fontSize: 9, letterSpacing: 0.6, textTransform: 'uppercase', color: TERM.muted }}>
        <span>PUSH·A &nbsp;/&nbsp; UPPER·HYP &nbsp;/&nbsp; W3·5</span>
        <span style={{ color: TERM.ink, fontVariantNumeric: 'tabular-nums' }}>0:38:14</span>
      </div>

      <TermRule />

      {/* Exercise header */}
      <div style={{ padding: '14px 16px 12px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontFamily: TERM.display, fontSize: 22, fontWeight: 600,
              letterSpacing: -0.4, lineHeight: 1.05, whiteSpace: 'nowrap',
              overflow: 'hidden', textOverflow: 'ellipsis' }}>
              Bench Press
            </div>
            <div style={{ fontSize: 9, color: TERM.muted, marginTop: 5, letterSpacing: 0.6, textTransform: 'uppercase' }}>
              Chest · Barbell · Ex 1 / 5
            </div>
          </div>
          <div style={{ textAlign: 'right', flexShrink: 0 }}>
            <TermSpark values={window.E1RM_HISTORY} />
            <div style={{ fontSize: 9, color: TERM.good, marginTop: 2, fontVariantNumeric: 'tabular-nums', letterSpacing: 0.4 }}>
              e1RM&nbsp;248&nbsp;↑4
            </div>
          </div>
        </div>
      </div>

      <TermRule label="CURRENT" />

      {/* HERO: weight × reps × RPE OR rest timer */}
      <div style={{ padding: '18px 16px 14px', position: 'relative' }}>
        {!resting ? (
          <>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
              <div style={{ fontSize: 9, color: TERM.muted, letterSpacing: 0.6 }}>
                SET&nbsp;<span style={{ color: TERM.ink, fontWeight: 600 }}>{S.setIdx + 1}</span>/{totalSets}
              </div>
              <div style={{
                fontSize: 9, color: TERM.signal, letterSpacing: 0.6,
                border: `0.5px solid ${TERM.signal}`, padding: '2px 6px',
              }}>
                {currentSet.intent?.toUpperCase() || 'WORKING'}
              </div>
            </div>

            {/* Big numerics in a 3-col grid */}
            <div style={{ display: 'grid', gridTemplateColumns: 'auto auto auto',
              alignItems: 'baseline', gap: 4, marginTop: 14, marginBottom: 6 }}>
              <span style={{ fontFamily: TERM.display, fontSize: 96, fontWeight: 500,
                lineHeight: 0.9, letterSpacing: -3, fontVariantNumeric: 'tabular-nums' }}>
                {currentSet.weight}
              </span>
              <span style={{ fontSize: 14, color: TERM.muted, padding: '0 6px' }}>×</span>
              <span style={{ fontFamily: TERM.display, fontSize: 56, fontWeight: 400,
                lineHeight: 0.9, letterSpacing: -1.5, fontVariantNumeric: 'tabular-nums' }}>
                {currentSet.reps}
              </span>
            </div>

            <div style={{ display: 'flex', gap: 18, fontSize: 9, color: TERM.muted,
              letterSpacing: 0.6, textTransform: 'uppercase' }}>
              <span>LB</span>
              <span style={{ marginLeft: 60 }}>REPS</span>
              <span style={{ marginLeft: 36, color: TERM.ink }}>@ RPE {currentSet.rpe}</span>
            </div>

            {/* Plate visualisation */}
            <div style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 9, color: TERM.muted, letterSpacing: 0.6 }}>BAR&nbsp;/</span>
              <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 2 }}>
                <div style={{ width: 8, height: 4, background: TERM.muted }} />
                <div style={{ width: 28, height: 2, background: TERM.muted }} />
                {window.platesFor(currentSet.weight).map((p, i) => {
                  const h = 28 + p * 0.3;
                  const w = Math.max(4, Math.min(14, p * 0.35));
                  return (
                    <div key={i} style={{
                      width: w, height: h, background: TERM.ink,
                      borderRight: `0.5px solid ${TERM.bg}`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <span style={{ fontSize: 7, color: TERM.bg, transform: 'rotate(-90deg)',
                        fontFamily: TERM.font }}>{p}</span>
                    </div>
                  );
                })}
                <div style={{ flex: 1, height: 2, background: TERM.muted }} />
              </div>
              <span style={{ fontSize: 9, color: TERM.muted, letterSpacing: 0.6,
                fontVariantNumeric: 'tabular-nums' }}>
                {window.platesFor(currentSet.weight).join('+')}
              </span>
            </div>
          </>
        ) : (
          <>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <span style={{ fontSize: 9, color: TERM.muted, letterSpacing: 0.6 }}>REST · AUTO</span>
              <span style={{ fontSize: 9, color: TERM.muted, fontVariantNumeric: 'tabular-nums' }}>
                / {fmtSec(restTotal)}
              </span>
            </div>
            <div style={{ fontFamily: TERM.display, fontSize: 110, fontWeight: 500,
              letterSpacing: -3, lineHeight: 0.9, marginTop: 8, fontVariantNumeric: 'tabular-nums' }}>
              {fmtSec(restRemaining)}
            </div>
            <div style={{ marginTop: 8, height: 2, background: TERM.ruleSoft, position: 'relative' }}>
              <div style={{ position: 'absolute', inset: 0,
                width: `${(restRemaining / restTotal) * 100}%`,
                background: TERM.ink, transition: 'width 1s linear' }} />
            </div>
            <div style={{ marginTop: 14, fontSize: 9, color: TERM.muted, letterSpacing: 0.6 }}>
              NEXT&nbsp;·&nbsp;<span style={{ color: TERM.ink, fontVariantNumeric: 'tabular-nums' }}>
                {currentSet.weight} × {currentSet.reps} @ {currentSet.rpe}</span>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              <button onClick={() => addRest(30)} style={{
                flex: 1, padding: '10px 0', border: `0.5px solid ${TERM.rule}`,
                background: 'transparent', fontFamily: TERM.font, fontSize: 10,
                letterSpacing: 0.6, cursor: 'pointer', color: TERM.ink,
              }}>+ 0:30</button>
              <button onClick={() => skipRest()} style={{
                flex: 1, padding: '10px 0', border: `0.5px solid ${TERM.ink}`,
                background: TERM.ink, color: TERM.bg, fontFamily: TERM.font,
                fontSize: 10, letterSpacing: 0.6, cursor: 'pointer',
              }}>SKIP REST →</button>
            </div>
          </>
        )}
      </div>

      <TermRule label="LOG" />

      {/* Set table */}
      <div style={{ padding: '12px 16px 8px', fontSize: 10, flex: 1, overflow: 'hidden' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '18px 38px 1fr 38px 30px 26px',
          gap: 6, fontSize: 8.5, letterSpacing: 0.6, color: TERM.muted, marginBottom: 6 }}>
          <span>#</span><span>KIND</span><span>LB</span>
          <span style={{ textAlign: 'right' }}>REPS</span>
          <span style={{ textAlign: 'right' }}>RPE</span>
          <span></span>
        </div>
        {exercise.sets.map((s, i) => {
          const isCur = i === S.setIdx && !resting;
          return (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '18px 38px 1fr 38px 30px 26px',
              gap: 6, alignItems: 'center', padding: '5px 0',
              borderBottom: `0.5px dashed ${TERM.ruleSoft}`,
              fontVariantNumeric: 'tabular-nums',
              color: s.done ? TERM.muted : TERM.ink,
              background: isCur ? '#0F13110A' : 'transparent',
              marginInline: isCur ? -6 : 0, paddingInline: isCur ? 6 : 0,
            }}>
              <span style={{ color: TERM.faint }}>{String(i + 1).padStart(2, '0')}</span>
              <span style={{ fontSize: 9, letterSpacing: 0.4 }}>{kindLabel[s.kind]}</span>
              <span style={{ fontFamily: TERM.display, fontSize: 13 }}>{s.weight}</span>
              <span style={{ textAlign: 'right', fontFamily: TERM.display, fontSize: 13 }}>{s.actualReps ?? s.reps}</span>
              <span style={{ textAlign: 'right', fontFamily: TERM.display, fontSize: 13 }}>{s.actualRpe ?? s.rpe}</span>
              <span style={{ textAlign: 'right', color: s.done ? TERM.good : isCur ? TERM.signal : TERM.faint }}>
                {s.done ? '✓' : isCur ? '◆' : '·'}
              </span>
            </div>
          );
        })}
      </div>

      {/* Footer */}
      <TermRule />
      <div style={{ padding: '10px 16px', display: 'flex', justifyContent: 'space-between',
        fontSize: 9, letterSpacing: 0.6, color: TERM.muted }}>
        <span>LAST&nbsp;·&nbsp;<span style={{ color: TERM.ink }}>195 × 8 @ 8.5</span></span>
        <span>VOL&nbsp;·&nbsp;<span style={{ color: TERM.ink, fontVariantNumeric: 'tabular-nums' }}>4,610 lb</span></span>
        <span>e1RM&nbsp;·&nbsp;<span style={{ color: TERM.good, fontVariantNumeric: 'tabular-nums' }}>248 ↑4</span></span>
      </div>

      {!resting ? (
        <div style={{ padding: '0 16px 28px' }}>
          <button onClick={() => logSet()} style={{
            width: '100%',
            background: TERM.ink, color: TERM.bg, border: 'none',
            fontFamily: TERM.font, fontSize: 11, letterSpacing: 2,
            cursor: 'pointer', display: 'flex', justifyContent: 'space-between',
            alignItems: 'center', padding: '14px 16px', boxSizing: 'border-box',
          }}>
            <span style={{ whiteSpace: 'nowrap' }}>LOG&nbsp;SET</span>
            <span style={{ color: TERM.faint }}>↵</span>
          </button>
        </div>
      ) : (
        <div style={{ margin: '0 16px 28px', padding: '14px 16px',
          border: `0.5px solid ${TERM.rule}`, display: 'flex',
          justifyContent: 'space-between', fontSize: 10, color: TERM.muted, letterSpacing: 0.6, boxSizing: 'border-box' }}>
          <span>RESTING — AUTO-RESUME</span>
          <span style={{ color: TERM.ink, fontVariantNumeric: 'tabular-nums' }}>{fmtSec(restRemaining)}</span>
        </div>
      )}
    </div>
  );
}

window.TerminalVariant = TerminalVariant;
