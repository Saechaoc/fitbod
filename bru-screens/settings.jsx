// Phase 6 · Settings + Export · CSV/JSON · backup/restore · per-equipment plate inv

function BruSettingsScreen() {
  const Row = ({ label, value, onTap, accent, last }) => (
    <div onClick={onTap} style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '12px 16px',
      borderBottom: last ? 'none' : `1px solid ${BRU.hair}`,
      cursor: 'pointer',
    }}>
      <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: accent || BRU.ink }}>{label}</span>
      {value && <span style={{ fontFamily: BRU.mono, fontSize: 11, color: BRU.muted }}>
        {value}
      </span>}
      <span style={{ color: BRU.muted, fontSize: 14 }}>›</span>
    </div>
  );

  return (
    <BruPhone>
      <BruHeader left="‹" center="Settings" right="" />

      <div style={{ flex: 1, overflow: 'auto' }}>
        {/* Profile */}
        <div style={{ padding: '16px', borderBottom: `2px solid ${BRU.ink}`,
          display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 56, height: 56, background: BRU.ink, color: BRU.paper,
            fontFamily: BRU.display, fontSize: 36, lineHeight: '56px',
            textAlign: 'center', letterSpacing: 0,
          }}>J</div>
          <div>
            <BruDisplay size={28}>James M.</BruDisplay>
            <div style={{ fontSize: 10, color: BRU.muted, letterSpacing: 1, fontWeight: 700 }}>
              42 SESSIONS · BLOCK 03 · WEEK 3
            </div>
          </div>
        </div>

        <BruSectionHead>Units &amp; calibration</BruSectionHead>
        <Row label="Units" value="LB" />
        <Row label="Plate inventory" value="HOME GYM · 6 PAIRS" />
        <Row label="Per-exercise increment" value="DEFAULT 5 LB" />
        <Row label="RPE calibration window" value="10 SETS" last />

        <BruSectionHead>Training defaults</BruSectionHead>
        <Row label="Rest defaults" value="TOP 4M · WORK 3M" />
        <Row label="Auto-start rest timer" value="ON" />
        <Row label="Live activity" value="DYNAMIC ISLAND" />
        <Row label="Stall threshold" value="± 2% · 3 SESSIONS" last />

        <BruSectionHead>Volume targets</BruSectionHead>
        <Row label="MEV / MAV / MRV thresholds" value="STANDARD · RP" />
        <Row label="Stimulus weights" value="50 LIFTS CURATED" last />

        <BruSectionHead right="LAST · MAY 18">Export</BruSectionHead>
        {/* Export options as buttons */}
        <div style={{ padding: '8px 16px', display: 'grid', gridTemplateColumns: '1fr 1fr',
          gap: 8 }}>
          {[
            { kind: 'CSV', label: 'Export CSV', sub: 'ONE ROW PER SET' },
            { kind: 'JSON', label: 'Export JSON', sub: 'VERSION-STAMPED' },
          ].map((e, i) => (
            <div key={i} style={{
              border: `2px solid ${BRU.ink}`, padding: '12px 12px',
              display: 'flex', flexDirection: 'column', gap: 4,
            }}>
              <BruDisplay size={28}>{e.kind}</BruDisplay>
              <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.5 }}>
                {e.label}
              </div>
              <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1, fontWeight: 700 }}>
                {e.sub}
              </div>
            </div>
          ))}
        </div>

        {/* Backup / restore */}
        <div style={{ margin: '12px 16px', border: `2px solid ${BRU.ink}` }}>
          <div style={{ padding: '12px 14px', borderBottom: `1px solid ${BRU.ink}` }}>
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5, color: BRU.muted }}>
              FULL BACKUP
            </div>
            <BruDisplay size={22}>iCloud · 2 days ago</BruDisplay>
            <div style={{ fontSize: 11, marginTop: 4, color: BRU.muted }}>
              42 sessions · 812 exercises · 3 blocks
            </div>
          </div>
          <div style={{ display: 'flex' }}>
            <button style={{
              flex: 1, padding: '10px 0', border: 'none', cursor: 'pointer',
              background: 'transparent', borderRight: `1px solid ${BRU.ink}`,
              fontFamily: BRU.font, fontSize: 11, fontWeight: 700, letterSpacing: 1.2,
            }}>
              CREATE
            </button>
            <button style={{
              flex: 1, padding: '10px 0', border: 'none', cursor: 'pointer',
              background: BRU.signal, color: BRU.paper,
              fontFamily: BRU.font, fontSize: 11, fontWeight: 700, letterSpacing: 1.2,
            }}>
              RESTORE
            </button>
          </div>
        </div>

        <BruSectionHead>About</BruSectionHead>
        <Row label="Version" value="1.0.0 · SCHEMA V1" />
        <Row label="Source" value="MIT · GITHUB" />
        <Row label="Reset all data" accent={BRU.signal} last />
      </div>

      <BruTabBar active="today" />
    </BruPhone>
  );
}

window.BruSettingsScreen = BruSettingsScreen;
