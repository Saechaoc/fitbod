// Phase 4 · Block Builder  (reference-matched redesign)
// Bold title · stat cards · compact multi-phase preview graph · phase rows

function BruBlockBuilderScreen() {
  // Phase palette
  const P = {
    blue: '#2F5DA8',
    red: '#D8492E',
    green: '#2E7D52',
    amber: '#C68A1C',
    purple: '#8A5071'
  };
  const cardBg = '#FBFAF5';
  const cardBd = 'rgba(10,10,10,0.10)';
  const titleFont = '-apple-system, "Helvetica Neue", system-ui, sans-serif';

  const phases = [
  { n: '01', name: 'Accumulation', sub: 'Build volume', wks: '2', vol: '+20%', int: '70%', color: P.blue },
  { n: '02', name: 'Intensification', sub: 'Build strength', wks: '2', vol: 'Hold', int: '85%', color: P.red },
  { n: '03', name: 'Deload', sub: 'Recover', wks: '1', vol: '−50%', int: '70%', color: P.green },
  { n: '04', name: 'Peak', sub: 'Sharpen output', wks: '1', vol: '−20%', int: '92%', color: P.amber },
  { n: '05', name: 'Realization', sub: 'Test maxes', wks: '1', vol: '−40%', int: '100%', color: P.purple }];


  const lbl = { fontSize: 9, color: BRU.muted, letterSpacing: 1.4, fontWeight: 700, textTransform: 'uppercase' };

  // ── Compact preview graph ───────────────────────────────
  // 7 week columns; phase bands by week span.
  const W = 320,H = 124,x0 = 6,x1 = 314,top = 22,bot = 96;
  const cols = 7,cw = (x1 - x0) / cols;
  const cx = (i) => x0 + cw * (i + 0.5);
  const y = (v) => bot - v / 100 * (bot - top);
  const bands = [
  { span: [0, 2], label: 'Accum.', color: P.blue },
  { span: [2, 4], label: 'Intens.', color: P.red },
  { span: [4, 5], label: 'Deload', color: P.green },
  { span: [5, 6], label: 'Peak', color: P.amber },
  { span: [6, 7], label: 'Real.', color: P.purple }];

  const intensity = [70, 70, 85, 85, 70, 92, 100];
  const volume = [48, 70, 76, 78, 40, 56, 42];
  const intPts = intensity.map((v, i) => `${cx(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const volPts = volume.map((v, i) => `${cx(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');

  const StepBtn = ({ children }) =>
  <button style={{
    width: 38, height: 38, borderRadius: 19, border: `1.5px solid ${cardBd}`,
    background: BRU.paper, color: BRU.ink, fontSize: 22, fontWeight: 500,
    lineHeight: 1, cursor: 'pointer', display: 'flex', alignItems: 'center',
    justifyContent: 'center', fontFamily: BRU.font
  }}>{children}</button>;


  return (
    <BruPhone right={
    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <svg width="17" height="11" viewBox="0 0 17 11"><g fill={BRU.ink}>
          <rect x="0" y="7" width="3" height="4" rx="0.5" />
          <rect x="4.5" y="5" width="3" height="6" rx="0.5" />
          <rect x="9" y="2.5" width="3" height="8.5" rx="0.5" />
          <rect x="13.5" y="0" width="3" height="11" rx="0.5" />
        </g></svg>
        <svg width="22" height="11" viewBox="0 0 25 12"><rect x="0.5" y="0.5" width="21" height="11" rx="3" fill="none" stroke={BRU.ink} strokeOpacity="0.4" /><rect x="2" y="2" width="16.5" height="8" rx="1.5" fill={BRU.ink} /><rect x="23" y="3.5" width="1.6" height="5" rx="0.8" fill={BRU.ink} fillOpacity="0.4" /></svg>
      </span>
    }>
      <BruHeader left="‹" center="Program" right={<span style={{ color: BRU.signal }}>SAVE</span>} />

      <div style={{ flex: 1, overflow: 'auto', WebkitOverflowScrolling: 'touch' }}>
        {/* Title */}
        <div style={{ padding: '18px 20px 4px', display: 'flex',
          alignItems: 'flex-start', justifyContent: 'space-between', gap: 14 }}>
          <div>
            <div style={lbl}>Block name</div>
            <div style={{ fontFamily: titleFont, fontWeight: 800, fontSize: 44,
              lineHeight: 0.92, letterSpacing: -1.5, textTransform: 'uppercase',
              marginTop: 6, color: BRU.ink }}>
              Hypertrophy<br />Meso
            </div>
          </div>
          <button style={{
            width: 42, height: 42, borderRadius: 21, flexShrink: 0,
            border: `1.5px solid ${cardBd}`, background: BRU.paper, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: 18
          }}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke={BRU.ink} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M11 2.5 13.5 5 5 13.5 2 14l0.5-3z" />
            </svg>
          </button>
        </div>

        {/* Stat cards */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, padding: '14px 20px 0' }}>
          <div style={{ background: cardBg, border: `1.5px solid ${cardBd}`, borderRadius: 16, padding: '14px 16px' }}>
            <div style={lbl}>Total weeks</div>
            <div style={{ fontFamily: titleFont, fontWeight: 800, fontSize: 46, lineHeight: 1, marginTop: 4 }}>7</div>
            <div style={{ ...lbl, marginTop: 6 }}>From phases</div>
          </div>
          <div style={{ background: cardBg, border: `1.5px solid ${cardBd}`, borderRadius: 16, padding: '14px 16px' }}>
            <div style={lbl}>Days / week</div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 8 }}>
              <StepBtn>−</StepBtn>
              <div style={{ fontFamily: titleFont, fontWeight: 800, fontSize: 46, lineHeight: 1 }}>4</div>
              <StepBtn>+</StepBtn>
            </div>
          </div>
        </div>

        {/* Preview */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '22px 20px 8px' }}>
          <span style={{ ...lbl, fontSize: 11 }}>Preview</span>
          <span style={{ ...lbl, border: `1.5px solid ${cardBd}`, borderRadius: 20, padding: '4px 10px', color: BRU.muted }}>7 Week Mesocycle</span>
        </div>
        <div style={{ margin: '0 20px', background: cardBg, border: `1.5px solid ${cardBd}`, borderRadius: 16, overflow: 'hidden' }}>
          {/* legend */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '10px 14px', borderBottom: `1px solid ${cardBd}` }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 12, color: BRU.ink2 }}>
              <span style={{ width: 22, height: 3, background: 'rgba(10,10,10,0.3)', borderRadius: 2,
                backgroundImage: 'repeating-linear-gradient(90deg, rgba(10,10,10,0.45) 0 4px, transparent 4px 7px)' }} />
              Volume
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 12, color: BRU.ink }}>
              <span style={{ display: 'flex', alignItems: 'center' }}>
                <span style={{ width: 6, height: 6, borderRadius: 3, background: BRU.ink }} />
                <span style={{ width: 16, height: 2.5, background: BRU.ink }} />
                <span style={{ width: 6, height: 6, borderRadius: 3, background: BRU.ink }} />
              </span>
              Intensity
            </span>
          </div>
          {/* chart */}
          <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: 'block' }}>
            {bands.map((b, i) => {
              const bx = x0 + cw * b.span[0];
              const bw = cw * (b.span[1] - b.span[0]);
              return (
                <g key={i}>
                  <rect x={bx} y={top - 6} width={bw} height={bot - top + 6} fill={b.color} fillOpacity={0.10} />
                  <text x={bx + bw / 2} y={14} textAnchor="middle" fill={b.color}
                  style={{ fontSize: 9, fontWeight: 700, letterSpacing: 0.2 }}>{b.label}</text>
                </g>);

            })}
            {/* volume area + dashed line */}
            <polyline points={volPts} fill="none" stroke="rgba(10,10,10,0.35)" strokeWidth="1.5"
            strokeDasharray="4 3" strokeLinejoin="round" strokeLinecap="round" />
            {/* intensity solid line */}
            <polyline points={intPts} fill="none" stroke={BRU.ink} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
            {intensity.map((v, i) =>
            <circle key={i} cx={cx(i)} cy={y(v)} r={3.2} fill={BRU.ink} />
            )}
            {/* x labels */}
            {[0, 1, 2, 3, 4, 5, 6].map((i) =>
            <text key={i} x={cx(i)} y={H - 6} textAnchor="middle" fill={BRU.muted}
            style={{ fontSize: 9, fontFamily: BRU.mono }}>{`W${i + 1}`}</text>
            )}
          </svg>
        </div>
        <div style={{ padding: '12px 20px 4px', fontSize: 13, lineHeight: 1.45, color: BRU.ink2 }}>

        </div>

        {/* Phases */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 20px 10px' }}>
          <span style={{ ...lbl, fontSize: 11 }}>Phases · 5</span>
          <button style={{ ...lbl, border: `1.5px solid ${cardBd}`, borderRadius: 20, padding: '6px 12px',
            background: BRU.paper, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6, color: BRU.ink }}>
            <span style={{ color: BRU.signal, fontSize: 13, lineHeight: 1 }}>+</span> Add Phase
          </button>
        </div>
        <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {phases.map((ph) =>
          <div key={ph.n} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            background: BRU.paper, border: `1.5px solid ${cardBd}`, borderRadius: 12,
            borderLeft: `4px solid ${ph.color}`, padding: '12px 12px 12px 14px'
          }}>
              <div style={{
              width: 42, height: 42, borderRadius: 10, flexShrink: 0,
              background: ph.color, color: '#fff', display: 'flex',
              alignItems: 'center', justifyContent: 'center',
              fontFamily: titleFont, fontWeight: 800, fontSize: 18, letterSpacing: -0.5
            }}>{ph.n}</div>
              <div style={{ minWidth: 0, flex: '0 0 auto', width: 96 }}>
                <div style={{ fontSize: 15, fontWeight: 700, color: BRU.ink, whiteSpace: 'nowrap' }}>{ph.name}</div>
                <div style={{ fontSize: 11.5, color: BRU.muted, marginTop: 1 }}>{ph.sub}</div>
              </div>
              <div style={{ flex: 1, display: 'flex', justifyContent: 'space-between', gap: 4 }}>
                {[['Weeks', ph.wks], ['Vol', ph.vol], ['Int', ph.int]].map(([k, v]) =>
              <div key={k} style={{ textAlign: 'left' }}>
                    <div style={{ fontSize: 8, color: BRU.muted, letterSpacing: 1, fontWeight: 700, textTransform: 'uppercase' }}>{k}</div>
                    <div style={{ fontFamily: titleFont, fontWeight: 800, fontSize: 16, marginTop: 2, color: BRU.ink }}>{v}</div>
                  </div>
              )}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0, color: BRU.faint }}>
                <span style={{ fontSize: 11, letterSpacing: -2 }}>⋮⋮</span>
                <span style={{ fontSize: 16, color: BRU.muted }}>›</span>
              </div>
            </div>
          )}
        </div>
        <div style={{ height: 16 }} />
      </div>

      {/* Bottom action bar */}
      <div style={{ borderTop: `1px solid ${cardBd}`, padding: '12px 20px 22px',
        display: 'flex', gap: 10, background: BRU.bg }}>
        <button style={{
          flex: '0 0 38%', padding: '15px 0', borderRadius: 14, cursor: 'pointer',
          background: BRU.paper, border: `1.5px solid ${cardBd}`, color: BRU.ink2,
          fontFamily: BRU.font, fontSize: 12, fontWeight: 700, letterSpacing: 1.5, textTransform: 'uppercase'
        }}>Cancel</button>
        <button style={{
          flex: 1, padding: '15px 0', borderRadius: 14, cursor: 'pointer', border: 'none',
          background: BRU.ink, color: BRU.paper, fontFamily: BRU.font, fontSize: 12, fontWeight: 700,
          letterSpacing: 1.5, textTransform: 'uppercase', display: 'flex', alignItems: 'center',
          justifyContent: 'center', gap: 8
        }}>
          <svg width="11" height="13" viewBox="0 0 11 13" fill={BRU.paper}><path d="M0 0h11v13L5.5 9.2 0 13z" /></svg>
          Save Template
        </button>
      </div>
    </BruPhone>);

}

window.BruBlockBuilderScreen = BruBlockBuilderScreen;