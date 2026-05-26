// Phase 6 · Progress Chart · per-exercise intent-split time series

function BruProgressChartScreen() {
  // Generate two series — strength and hypertrophy e1RM over 12 weeks
  const wks = 12;
  const hyp = [212, 216, 220, 224, 228, 232, 236, 240, 244, 246, 247, 248];
  const str = [220, null, 226, null, 232, null, 240, null, 246, null, 252, null];

  // Chart geometry
  const CHART = { x: 16, y: 14, w: 360, h: 200, pad: { l: 32, r: 8, t: 8, b: 26 } };
  const lo = 200, hi = 260;
  const px = (i) => CHART.pad.l + (i / (wks - 1)) * (CHART.w - CHART.pad.l - CHART.pad.r);
  const py = (v) => CHART.pad.t + (1 - (v - lo) / (hi - lo)) * (CHART.h - CHART.pad.t - CHART.pad.b);
  const polyline = (vals) => vals.map((v, i) => v == null ? null : `${px(i).toFixed(1)},${py(v).toFixed(1)}`).filter(Boolean).join(' ');

  return (
    <BruPhone>
      <BruHeader left="‹" center="Bench · Progress" right="EXPORT" />

      {/* Hero summary */}
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}`,
        display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5, color: BRU.muted }}>
            EST. 1 REP MAX · 12 WEEKS
          </div>
          <BruDisplay size={60}>248 LB</BruDisplay>
        </div>
        <div style={{ textAlign: 'right' }}>
          <BruChip fill color={BRU.signal}>+ 36 LB</BruChip>
          <div style={{ fontSize: 9, color: BRU.muted, marginTop: 6, letterSpacing: 1.2 }}>
            FROM 212 LB
          </div>
        </div>
      </div>

      {/* Series toggle */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        {[
          { l: 'e1RM',       active: true },
          { l: 'TOP SET' },
          { l: 'VOLUME' },
          { l: 'AVG RPE' },
        ].map((t, i) => (
          <div key={t.l} style={{
            flex: 1, padding: '8px 4px', textAlign: 'center',
            fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
            borderRight: i < 3 ? `1px solid ${BRU.ink}` : 'none',
            background: t.active ? BRU.ink : 'transparent',
            color: t.active ? BRU.paper : BRU.ink,
          }}>{t.l}</div>
        ))}
      </div>

      {/* Chart */}
      <div style={{ padding: '8px 12px', borderBottom: `2px solid ${BRU.ink}` }}>
        <svg width={CHART.w} height={CHART.h}>
          {/* Y grid + labels */}
          {[200, 220, 240, 260].map(v => (
            <g key={v}>
              <line x1={CHART.pad.l} x2={CHART.w - CHART.pad.r} y1={py(v)} y2={py(v)}
                stroke={BRU.hair} strokeWidth="1" strokeDasharray="2,3" />
              <text x={CHART.pad.l - 6} y={py(v) + 3} textAnchor="end"
                fontSize="9" fontFamily={BRU.mono} fill={BRU.muted}>{v}</text>
            </g>
          ))}
          {/* PR marker (latest) */}
          <line x1={CHART.pad.l} x2={CHART.w - CHART.pad.r}
            y1={py(248)} y2={py(248)} stroke={BRU.signal} strokeDasharray="4,2" strokeWidth="1" />
          <text x={CHART.w - CHART.pad.r - 4} y={py(248) - 4} textAnchor="end"
            fontSize="9" fontFamily={BRU.mono} fill={BRU.signal} fontWeight="700">PR 248</text>

          {/* Hypertrophy series (filled area) */}
          <polygon
            points={`${px(0)},${py(lo)} ${polyline(hyp)} ${px(wks - 1)},${py(lo)}`}
            fill={BRU.ink} fillOpacity={0.06} />
          <polyline points={polyline(hyp)} fill="none" stroke={BRU.ink} strokeWidth="2" />
          {hyp.map((v, i) => (
            <rect key={i} x={px(i) - 2.5} y={py(v) - 2.5} width="5" height="5" fill={BRU.ink} />
          ))}

          {/* Strength series (dashed, signal red) */}
          <polyline points={polyline(str)} fill="none" stroke={BRU.signal}
            strokeWidth="2" strokeDasharray="6,3" />
          {str.map((v, i) => v != null && (
            <circle key={i} cx={px(i)} cy={py(v)} r="3.5" fill={BRU.signal} stroke={BRU.bg} strokeWidth="1.5" />
          ))}

          {/* X axis */}
          {[0, 3, 6, 9, 11].map(i => (
            <text key={i} x={px(i)} y={CHART.h - 6} textAnchor="middle"
              fontSize="9" fontFamily={BRU.mono} fill={BRU.muted}>W{i + 1}</text>
          ))}
        </svg>
        {/* Legend */}
        <div style={{ display: 'flex', gap: 16, fontSize: 9, fontWeight: 700,
          letterSpacing: 1.2, marginTop: 4 }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            <div style={{ width: 16, height: 2, background: BRU.ink }} />
            HYPERTROPHY · 9 SESSIONS
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            <svg width="16" height="2"><line x1="0" y1="1" x2="16" y2="1"
              stroke={BRU.signal} strokeWidth="2" strokeDasharray="3,2" /></svg>
            STRENGTH · 5 SESSIONS
          </span>
        </div>
      </div>

      {/* PRs strip */}
      <BruSectionHead right="ALL TIME">Personal records</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { kind: 'e1RM PR',  v: '248 LB',  when: 'TODAY · MAY 22', delta: '+4', current: true },
          { kind: 'TOP WEIGHT', v: '225 × 1',  when: 'JAN 14 · CALIBRATING', delta: null },
          { kind: 'TOP REPS',   v: '12 × 175', when: 'MAR 02 · HYP',         delta: '+1' },
          { kind: 'VOLUME PR',  v: '4,610 LB',  when: 'TODAY · MAY 22',       delta: '+200', current: true },
          { kind: 'e1RM PR · STR', v: '252 LB', when: 'PROJECTED · W5',       delta: null },
        ].map((p, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '110px 1fr auto',
            gap: 10, alignItems: 'baseline',
            padding: '10px 16px', borderBottom: `1px solid ${BRU.hair}`,
            background: p.current ? `${BRU.signal}0F` : 'transparent',
          }}>
            <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
              color: p.current ? BRU.signal : BRU.ink }}>{p.kind}</span>
            <BruDisplay size={20}>{p.v}</BruDisplay>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: BRU.mono, fontSize: 9, color: BRU.muted,
                letterSpacing: 0.5 }}>{p.when}</div>
              {p.delta && <div style={{ fontFamily: BRU.display, fontSize: 16,
                color: BRU.signal }}>{p.delta}</div>}
            </div>
          </div>
        ))}
      </div>

      <BruTabBar active="progress" />
    </BruPhone>
  );
}

window.BruProgressChartScreen = BruProgressChartScreen;
