// Phase 2 · Session History
// Vertical list of completed sessions · routine · duration · volume · PR badges

function BruSessionHistoryScreen() {
  const sessions = [
    { date: 'TODAY', day: 'WED 22', name: 'Push A', work: '4,610 lb', sets: '21 sets · 52m', pr: 'e1RM' },
    { date: 'MON 20', day: '', name: 'Pull A', work: '5,240 lb', sets: '19 sets · 48m', pr: null },
    { date: 'SAT 18', day: '', name: 'Legs A', work: '8,950 lb', sets: '24 sets · 1h12', pr: 'WEIGHT' },
    { date: 'THU 16', day: '', name: 'Push A', work: '4,420 lb', sets: '21 sets · 49m', pr: null },
    { date: 'TUE 14', day: '', name: 'Pull A', work: '5,180 lb', sets: '19 sets · 50m', pr: null },
    { date: 'SUN 12', day: '', name: 'Legs A', work: '8,820 lb', sets: '24 sets · 1h08', pr: null },
    { date: 'FRI 10', day: '', name: 'Push A', work: '4,310 lb', sets: '20 sets · 47m', pr: 'VOL' },
  ];
  return (
    <BruPhone>
      <BruHeader left="‹" center="History" right="FILTER" />

      {/* Top stats */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ flex: 1, padding: '12px 16px', borderRight: `1px solid ${BRU.ink}` }}>
          <BruReadout label="Sessions · 30d" value="14" />
        </div>
        <div style={{ flex: 1, padding: '12px 16px', borderRight: `1px solid ${BRU.ink}` }}>
          <BruReadout label="Tonnage" value="71.2k" color={BRU.signal} />
        </div>
        <div style={{ flex: 1, padding: '12px 16px' }}>
          <BruReadout label="Adherence" value="93%" />
        </div>
      </div>

      {/* Tonnage spark */}
      <div style={{ padding: '12px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, fontWeight: 700, letterSpacing: 1.5 }}>
          <span>WEEKLY TONNAGE · 8 wk</span>
          <span style={{ color: BRU.signal }}>↑ 12.4%</span>
        </div>
        <div style={{ marginTop: 8, height: 60, background: BRU.bg2,
          border: `1.5px solid ${BRU.ink}`, padding: 6, display: 'flex',
          alignItems: 'flex-end', gap: 4 }}>
          {[58, 62, 64, 61, 66, 68, 70, 71].map((v, i) => (
            <div key={i} style={{
              flex: 1, height: `${v}%`,
              background: i === 7 ? BRU.signal : BRU.ink,
            }} />
          ))}
        </div>
      </div>

      <BruSectionHead right={`${sessions.length} sessions`}>Past sessions</BruSectionHead>

      <div style={{ flex: 1, overflow: 'auto' }}>
        {sessions.map((s, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '64px 1fr auto',
            gap: 10, padding: '12px 16px',
            borderBottom: `1px solid ${BRU.hair}`,
            alignItems: 'center',
          }}>
            <div style={{ borderRight: `1px solid ${BRU.hair}`, paddingRight: 10 }}>
              <div style={{ fontFamily: BRU.display, fontSize: 18, lineHeight: 1, letterSpacing: 0.5 }}>
                {s.date}
              </div>
              {s.day && <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 0.8, marginTop: 2 }}>{s.day}</div>}
            </div>
            <div>
              <div style={{ fontSize: 14, fontWeight: 600 }}>{s.name}</div>
              <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 0.5,
                textTransform: 'uppercase', marginTop: 2 }}>{s.sets}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: BRU.display, fontSize: 18, fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>
                {s.work}
              </div>
              {s.pr ? (
                <BruChip color={BRU.signal} fill style={{ marginTop: 4, fontSize: 8 }}>
                  PR · {s.pr}
                </BruChip>
              ) : (
                <div style={{ fontSize: 9, color: BRU.muted, marginTop: 4 }}>›</div>
              )}
            </div>
          </div>
        ))}
      </div>

      <BruTabBar active="progress" />
    </BruPhone>
  );
}

window.BruSessionHistoryScreen = BruSessionHistoryScreen;
