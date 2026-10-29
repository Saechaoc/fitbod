// Variant E · EDITORIAL
// Serif headlines · cream paper · numbers as pull-quotes · italic prescriptions

const EDIT = {
  bg: '#F7F1E5',
  ink: '#1A1610',
  ink2: '#3A332A',
  muted: '#7A715F',
  faint: '#C8BFA8',
  rule: '#1A161020',
  accent: '#8B3A1A',     // sepia / burnt sienna
  accent2: '#2E5A3F',    // forest
  font: '"Söhne", "Public Sans", "Albert Sans", system-ui, sans-serif',
  serif: '"Newsreader", "Instrument Serif", "Cormorant Garamond", Georgia, serif',
  mono: '"JetBrains Mono", ui-monospace, monospace',
};

function EditRule({ style }) {
  return <div style={{ height: 1, background: EDIT.ink, opacity: 0.15, ...style }} />;
}

function EditorialVariant() {
  const S = useSession();
  const { exercise, currentSet, resting, restRemaining, restTotal,
    logSet, skipRest, addRest, completedCount, totalSets } = S;

  const intentLabel = {
    warmup: 'Warm-up', working: 'A working effort', top: 'Top set',
    backoff: 'A back-off', cluster: 'A cluster',
  }[currentSet.kind] || 'Working';

  return (
    <div style={{
      width: '100%', height: '100%', background: EDIT.bg, color: EDIT.ink,
      fontFamily: EDIT.font, display: 'flex', flexDirection: 'column',
      padding: '54px 0 0', boxSizing: 'border-box', position: 'relative',
    }}>
      {/* status */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between',
        padding: '17px 24px 0', fontSize: 14, fontWeight: 600 }}>
        <span style={{ fontFamily: EDIT.serif, fontWeight: 500 }}>9:41</span>
        <span style={{ fontFamily: EDIT.mono, fontSize: 11, letterSpacing: 1 }}>
          38:14 elapsed
        </span>
      </div>

      {/* Masthead */}
      <div style={{ padding: '8px 24px 14px',
        display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
        whiteSpace: 'nowrap' }}>
        <span style={{ fontFamily: EDIT.serif, fontSize: 14, fontStyle: 'italic',
          color: EDIT.muted }}>
          № 47 · Week III of V
        </span>
        <span style={{ fontFamily: EDIT.mono, fontSize: 10, letterSpacing: 2,
          color: EDIT.muted }}>
          PUSH · A
        </span>
      </div>

      <EditRule style={{ marginLeft: 24, marginRight: 24, height: 2, background: EDIT.ink, opacity: 1 }} />
      <EditRule style={{ marginLeft: 24, marginRight: 24, marginTop: 3 }} />

      {/* Exercise heading */}
      <div style={{ padding: '20px 24px 8px' }}>
        <div style={{ fontFamily: EDIT.mono, fontSize: 10, letterSpacing: 2,
          color: EDIT.muted, textTransform: 'uppercase' }}>
          Lift One of Five
        </div>
        <h1 style={{ fontFamily: EDIT.serif, fontSize: 40, fontWeight: 400,
          letterSpacing: -1, lineHeight: 0.95, margin: '6px 0 0' }}>
          Bench
          <span style={{ fontStyle: 'italic', color: EDIT.accent }}> Press</span>
        </h1>
      </div>

      {/* HERO – set or rest */}
      {!resting ? (
        <div style={{ padding: '14px 24px 6px' }}>
          {/* Prescription line */}
          <div style={{ fontFamily: EDIT.serif, fontSize: 18, fontStyle: 'italic',
            color: EDIT.ink2, lineHeight: 1.3 }}>
            {intentLabel} <span style={{ color: EDIT.muted, fontStyle: 'normal',
              fontFamily: EDIT.font, fontSize: 12, letterSpacing: 1, textTransform: 'uppercase' }}>
              · {String(S.setIdx + 1).padStart(2,'0')} of {String(totalSets).padStart(2,'0')}
            </span>
          </div>

          {/* Pull-quote number */}
          <div style={{ position: 'relative', marginTop: 4 }}>
            <div style={{ fontFamily: EDIT.serif, fontSize: 168, fontWeight: 300,
              lineHeight: 0.88, letterSpacing: -8, fontVariantNumeric: 'tabular-nums' }}>
              {currentSet.weight}
              <span style={{ fontSize: 30, fontStyle: 'italic',
                color: EDIT.accent, marginLeft: 8, verticalAlign: 'baseline',
                letterSpacing: 0 }}>lb</span>
            </div>
          </div>

          {/* Sub-prescription */}
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 10,
            marginTop: 8, fontFamily: EDIT.serif, fontSize: 22, fontWeight: 400,
            whiteSpace: 'nowrap' }}>
            <span style={{ fontStyle: 'italic', color: EDIT.muted, fontSize: 17 }}>for</span>
            <span style={{ fontVariantNumeric: 'tabular-nums' }}>{currentSet.reps}</span>
            <span style={{ fontStyle: 'italic', color: EDIT.muted, fontSize: 17 }}>reps at</span>
            <span style={{ fontVariantNumeric: 'tabular-nums', color: EDIT.accent }}>
              RPE&nbsp;{currentSet.rpe}
            </span>
          </div>
        </div>
      ) : (
        <div style={{ padding: '14px 24px 6px' }}>
          <div style={{ fontFamily: EDIT.serif, fontSize: 18, fontStyle: 'italic',
            color: EDIT.ink2 }}>
            An interval of rest
            <span style={{ color: EDIT.muted, fontStyle: 'normal',
              fontFamily: EDIT.font, fontSize: 12, letterSpacing: 1, textTransform: 'uppercase' }}>
              {' '}· of {fmtSec(restTotal)}
            </span>
          </div>
          <div style={{ fontFamily: EDIT.serif, fontSize: 168, fontWeight: 300,
            lineHeight: 0.88, letterSpacing: -6, marginTop: 4,
            fontVariantNumeric: 'tabular-nums' }}>
            {fmtSec(restRemaining)}
          </div>
          <div style={{ marginTop: 6, height: 2, background: EDIT.faint }}>
            <div style={{ height: '100%', background: EDIT.accent,
              width: `${(restRemaining/restTotal)*100}%`, transition: 'width 1s linear' }} />
          </div>
          <div style={{ marginTop: 14, display: 'flex', gap: 10 }}>
            <button onClick={() => addRest(30)} style={{
              flex: 1, padding: '12px 0', background: 'transparent',
              border: `1px solid ${EDIT.ink}`, color: EDIT.ink, borderRadius: 0,
              fontFamily: EDIT.serif, fontStyle: 'italic', fontSize: 15, cursor: 'pointer',
            }}>add 30 s</button>
            <button onClick={() => skipRest()} style={{
              flex: 1, padding: '12px 0', background: EDIT.ink, color: EDIT.bg,
              border: 'none', borderRadius: 0,
              fontFamily: EDIT.serif, fontStyle: 'italic', fontSize: 15, cursor: 'pointer',
            }}>begin set</button>
          </div>
          <div style={{ marginTop: 14, fontFamily: EDIT.serif, fontStyle: 'italic',
            fontSize: 15, color: EDIT.muted }}>
            Next: <span style={{ color: EDIT.ink }}>{currentSet.weight} × {currentSet.reps}</span> at
            <span style={{ color: EDIT.accent }}> RPE {currentSet.rpe}</span>.
          </div>
        </div>
      )}

      <EditRule style={{ marginLeft: 24, marginRight: 24, marginTop: 14 }} />

      {/* Footer ledger — sets as a table */}
      <div style={{ padding: '12px 24px 4px', flex: 1, minHeight: 0, overflow: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          marginBottom: 6, fontFamily: EDIT.mono, fontSize: 10, letterSpacing: 1.5,
          color: EDIT.muted, textTransform: 'uppercase' }}>
          <span>The Ledger</span>
          <span>{completedCount}/{totalSets} completed</span>
        </div>
        <div>
          {exercise.sets.map((s, i) => {
            const isCur = i === S.setIdx && !resting;
            const done = s.done;
            return (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '24px 1fr auto auto auto',
                gap: 10, alignItems: 'baseline',
                padding: '7px 0', borderBottom: `1px dotted ${EDIT.faint}`,
                color: done ? EDIT.muted : EDIT.ink,
              }}>
                <span style={{ fontFamily: EDIT.serif, fontSize: 16, fontStyle: 'italic',
                  color: isCur ? EDIT.accent : EDIT.muted }}>{i + 1}.</span>
                <span style={{ fontFamily: EDIT.serif, fontSize: 14, fontStyle: 'italic',
                  color: isCur ? EDIT.ink : EDIT.muted }}>
                  {{warmup:'a warm-up', working:'a working set', top:'the top set',
                    backoff:'a back-off', cluster:'a cluster'}[s.kind]}
                </span>
                <span style={{ fontFamily: EDIT.serif, fontSize: 17,
                  fontVariantNumeric: 'tabular-nums',
                  textDecoration: done ? 'line-through' : 'none',
                  textDecorationColor: EDIT.faint }}>{s.weight}</span>
                <span style={{ fontFamily: EDIT.serif, fontSize: 15, fontStyle: 'italic',
                  color: EDIT.muted, fontVariantNumeric: 'tabular-nums' }}>×{s.actualReps ?? s.reps}</span>
                <span style={{ fontFamily: EDIT.serif, fontSize: 14, fontStyle: 'italic',
                  color: EDIT.accent, fontVariantNumeric: 'tabular-nums', minWidth: 50, textAlign: 'right' }}>
                  RPE {s.actualRpe ?? s.rpe}
                </span>
              </div>
            );
          })}
        </div>

        <div style={{ marginTop: 10, fontFamily: EDIT.serif, fontStyle: 'italic',
          fontSize: 13, color: EDIT.muted, lineHeight: 1.4 }}>
          Last week, <span style={{ color: EDIT.ink }}>195 lb × 8</span> at
          <span> RPE 8.5</span>. Estimated 1RM now
          <span style={{ color: EDIT.accent2 }}> 248 lb </span>(↑ 4).
        </div>
      </div>

      <EditRule style={{ marginLeft: 24, marginRight: 24 }} />

      {/* CTA */}
      {!resting ? (
        <button onClick={() => logSet()} style={{
          margin: '12px 24px 24px', padding: '14px 0',
          background: EDIT.ink, color: EDIT.bg, border: 'none', borderRadius: 0,
          fontFamily: EDIT.serif, fontStyle: 'italic', fontSize: 22, fontWeight: 400,
          letterSpacing: 0.2, cursor: 'pointer',
        }}>
          Mark complete →
        </button>
      ) : (
        <div style={{ margin: '12px 24px 24px', textAlign: 'center',
          fontFamily: EDIT.serif, fontStyle: 'italic', fontSize: 14,
          color: EDIT.muted }}>
          Resting · ready in {fmtSec(restRemaining)}
        </div>
      )}
    </div>
  );
}

window.EditorialVariant = EditorialVariant;
