// Phase 1 + 6 · Exercise Detail
// Intent-split history · e1RM · PRs · last-session inline

function BruExerciseDetailScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹ Library" center="" right="EDIT" />

      {/* Title slab */}
      <div style={{ padding: '12px 16px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ display: 'flex', gap: 6, marginBottom: 6 }}>
          <BruChip>CHEST</BruChip>
          <BruChip>BARBELL</BruChip>
          <BruChip>HORIZONTAL PUSH</BruChip>
        </div>
        <BruDisplay size={48}>Bench Press</BruDisplay>
        <div style={{ fontSize: 11, color: BRU.muted, marginTop: 8, letterSpacing: 0.5,
          textTransform: 'uppercase' }}>
          Primary: Chest 1.0 · Secondary: Triceps 0.5, Front Delts 0.5
        </div>
      </div>

      {/* e1RM hero */}
      <div style={{
        background: BRU.ink, color: BRU.paper, padding: '14px 16px',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          alignItems: 'baseline' }}>
          <span style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700,
            opacity: 0.6 }}>EST. 1 REP MAX</span>
          <span style={{ fontSize: 10, letterSpacing: 1.5, color: BRU.signal,
            fontWeight: 700 }}>+ 16 LB · 30D</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 4 }}>
          <BruDisplay size={72} color={BRU.paper}>248</BruDisplay>
          <span style={{ fontFamily: BRU.display, fontSize: 24, opacity: 0.6 }}>LB</span>
        </div>
        {/* Mini sparkline */}
        <div style={{ marginTop: 10 }}>
          <BruSpark values={[222,225,228,230,232,232,236,238,240,244,246,248]}
            w={361} h={36} color={BRU.signal} fill />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          marginTop: 4, fontSize: 9, color: 'rgba(255,255,255,0.5)' }}>
          <span>12 WK AGO · 222</span>
          <span>NOW · 248</span>
        </div>
      </div>

      {/* Intent-split toggle + history */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        {[
          { id: 'all', label: 'ALL · 14', active: true },
          { id: 'str', label: 'STRENGTH · 5' },
          { id: 'hyp', label: 'HYPER · 9' },
        ].map(t => (
          <div key={t.id} style={{
            flex: 1, padding: '10px 4px', textAlign: 'center',
            fontSize: 10, fontWeight: 700, letterSpacing: 1.2,
            borderRight: t.id !== 'hyp' ? `1px solid ${BRU.ink}` : 'none',
            background: t.active ? BRU.ink : 'transparent',
            color: t.active ? BRU.paper : BRU.ink, cursor: 'pointer',
          }}>{t.label}</div>
        ))}
      </div>

      {/* History rows */}
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { date: 'TODAY',    intent: 'HYP', sets: ['95×8 @4','135×6 @5','165×8 @7','185×8 @8','205×8 @9','175×10 @8'], top: '205×8 @9', e1rm: 248, pr: true },
          { date: 'THU MAY 16',intent: 'HYP', sets: ['95×8','135×6','165×8','185×8','195×8','170×10'], top: '195×8 @8.5', e1rm: 244 },
          { date: 'MON MAY 13',intent: 'STR', sets: ['95×5','135×5','185×5','205×3','215×2'], top: '215×2 @9', e1rm: 240 },
          { date: 'THU MAY 09',intent: 'HYP', sets: ['95×8','135×6','185×8','190×8','170×10'], top: '190×8 @8.5', e1rm: 238 },
          { date: 'MON MAY 06',intent: 'STR', sets: ['95×5','135×5','185×5','205×3','210×2'], top: '210×2 @9', e1rm: 236 },
        ].map((s, i) => (
          <div key={i} style={{ padding: '12px 16px', borderBottom: `1px solid ${BRU.hair}` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between',
              alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontFamily: BRU.display, fontSize: 18 }}>{s.date}</span>
                <BruChip color={s.intent === 'STR' ? BRU.signal : BRU.ink}>{s.intent}</BruChip>
                {s.pr && <BruChip fill color={BRU.signal}>★ PR</BruChip>}
              </div>
              <span style={{ fontFamily: BRU.display, fontSize: 18,
                fontVariantNumeric: 'tabular-nums' }}>
                e1RM&nbsp;{s.e1rm}
              </span>
            </div>
            <div style={{ marginTop: 6, fontFamily: BRU.mono, fontSize: 11,
              color: BRU.muted, letterSpacing: 0.3 }}>
              TOP <span style={{ color: BRU.ink, fontWeight: 600 }}>{s.top}</span>
              <span style={{ marginLeft: 10 }}>· {s.sets.length} sets</span>
            </div>
            {/* Set chips */}
            <div style={{ marginTop: 6, display: 'flex', gap: 4, flexWrap: 'wrap' }}>
              {s.sets.map((x, j) => (
                <span key={j} style={{
                  fontFamily: BRU.mono, fontSize: 10,
                  padding: '2px 6px', border: `1px solid ${BRU.hair}`,
                  background: i === 0 && j === s.sets.length - 2 ? BRU.signal : 'transparent',
                  color: i === 0 && j === s.sets.length - 2 ? BRU.paper : BRU.ink,
                  letterSpacing: 0.3,
                }}>{x}</span>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* PR strip footer */}
      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        {[
          { l: 'TOP WEIGHT', v: '225', sub: 'JAN' },
          { l: 'TOP REPS', v: '12', sub: '@175' },
          { l: 'VOL PR', v: '4,610', sub: 'TODAY', accent: true },
        ].map((p, i) => (
          <div key={i} style={{
            flex: 1, padding: '10px 12px',
            borderRight: i < 2 ? `1px solid ${BRU.ink}` : 'none',
            background: p.accent ? BRU.signal : 'transparent',
            color: p.accent ? BRU.paper : BRU.ink,
          }}>
            <div style={{ fontSize: 9, letterSpacing: 1.2, fontWeight: 700 }}>{p.l}</div>
            <div style={{ fontFamily: BRU.display, fontSize: 22, lineHeight: 1, marginTop: 2 }}>{p.v}</div>
            <div style={{ fontSize: 9, marginTop: 2, opacity: 0.7 }}>{p.sub}</div>
          </div>
        ))}
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruExerciseDetailScreen = BruExerciseDetailScreen;
