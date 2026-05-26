// Phase 1 · Exercise Library
// Search + multi-facet filter (muscle, equipment, mechanic, pattern) + indexed list

function BruLibraryScreen() {
  const exercises = [
    { name: 'Bench Press',           muscle: 'CHEST',  equip: 'BARBELL',  mech: 'COMPOUND', star: true,  count: 247 },
    { name: 'Bench Press · Close',   muscle: 'TRI',    equip: 'BARBELL',  mech: 'COMPOUND', star: false, count: 12  },
    { name: 'Bench Press · Incline', muscle: 'CHEST',  equip: 'BARBELL',  mech: 'COMPOUND', star: true,  count: 41  },
    { name: 'Bench Press · DB',      muscle: 'CHEST',  equip: 'DB',       mech: 'COMPOUND', star: false, count: 18  },
    { name: 'Bench Press · DB Incline', muscle: 'CHEST', equip: 'DB',     mech: 'COMPOUND', star: true,  count: 84  },
    { name: 'Bench Pin Press',       muscle: 'CHEST',  equip: 'BARBELL',  mech: 'COMPOUND', star: false, count: 4   },
    { name: 'Bent-Over Row',         muscle: 'BACK',   equip: 'BARBELL',  mech: 'COMPOUND', star: true,  count: 92  },
    { name: 'Bent-Over Row · Pendlay', muscle: 'BACK', equip: 'BARBELL',  mech: 'COMPOUND', star: false, count: 0   },
  ];
  return (
    <BruPhone>
      <BruHeader left="‹" center="Library" right="+ NEW" />

      {/* Search bar */}
      <div style={{
        padding: '10px 16px', borderBottom: `2px solid ${BRU.ink}`,
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <span style={{ fontFamily: BRU.display, fontSize: 18, lineHeight: 1 }}>🔍︎</span>
        <input
          defaultValue="bench"
          style={{
            flex: 1, border: 'none', background: 'transparent',
            fontFamily: BRU.font, fontSize: 16, fontWeight: 500,
            color: BRU.ink, outline: 'none',
          }}
        />
        <span style={{ fontFamily: BRU.mono, fontSize: 11, color: BRU.muted }}>8 / 812</span>
      </div>

      {/* Filter chips */}
      <div style={{ padding: '10px 16px', borderBottom: `2px solid ${BRU.ink}`,
        display: 'flex', gap: 6, overflowX: 'auto', whiteSpace: 'nowrap' }}>
        <BruChip fill>All</BruChip>
        <BruChip fill color={BRU.signal}>Chest ×</BruChip>
        <BruChip fill color={BRU.signal}>Barbell ×</BruChip>
        <BruChip>+ Equipment</BruChip>
        <BruChip>+ Pattern</BruChip>
        <BruChip>Custom</BruChip>
      </div>

      {/* Facet quick rows */}
      <div style={{ display: 'flex', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ flex: 1, padding: '8px 12px', borderRight: `1px solid ${BRU.hair}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1, fontWeight: 700 }}>MUSCLE</div>
          <div style={{ fontSize: 12, fontWeight: 600 }}>Chest</div>
        </div>
        <div style={{ flex: 1, padding: '8px 12px', borderRight: `1px solid ${BRU.hair}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1, fontWeight: 700 }}>EQUIP</div>
          <div style={{ fontSize: 12, fontWeight: 600 }}>Barbell</div>
        </div>
        <div style={{ flex: 1, padding: '8px 12px', borderRight: `1px solid ${BRU.hair}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1, fontWeight: 700 }}>MECH</div>
          <div style={{ fontSize: 12, fontWeight: 600 }}>Any</div>
        </div>
        <div style={{ flex: 1, padding: '8px 12px' }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1, fontWeight: 700 }}>PATTERN</div>
          <div style={{ fontSize: 12, fontWeight: 600 }}>Any</div>
        </div>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflow: 'auto' }}>
        {/* Indexed header */}
        <div style={{
          padding: '6px 16px', background: BRU.bg2,
          borderBottom: `1px solid ${BRU.ink}`,
          fontFamily: BRU.display, fontSize: 18, lineHeight: 1,
        }}>B</div>
        {exercises.map((e, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '20px 1fr auto',
            gap: 10, padding: '12px 16px', alignItems: 'center',
            borderBottom: `1px solid ${BRU.hair}`,
            background: i === 0 ? `${BRU.signal}0F` : 'transparent',
          }}>
            <span style={{ fontSize: 14, color: e.star ? BRU.signal : BRU.faint }}>
              {e.star ? '★' : '☆'}
            </span>
            <div>
              <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: -0.2 }}>{e.name}</div>
              <div style={{ display: 'flex', gap: 5, marginTop: 4 }}>
                <BruChip>{e.muscle}</BruChip>
                <BruChip>{e.equip}</BruChip>
                <BruChip>{e.mech}</BruChip>
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: BRU.mono, fontSize: 11, color: BRU.muted }}>
                {e.count}×
              </div>
              <div style={{ fontSize: 8, color: BRU.muted, letterSpacing: 1, marginTop: 2 }}>LOGGED</div>
            </div>
          </div>
        ))}

        {/* Section header for next letter */}
        <div style={{
          padding: '6px 16px', background: BRU.bg2,
          borderBottom: `1px solid ${BRU.ink}`, borderTop: `1px solid ${BRU.ink}`,
          fontFamily: BRU.display, fontSize: 18, lineHeight: 1,
        }}>C</div>
        <div style={{ padding: '12px 16px', display: 'grid',
          gridTemplateColumns: '20px 1fr auto', gap: 10, alignItems: 'center',
          color: BRU.muted, fontStyle: 'italic', fontSize: 11 }}>
          <span /><span>(0 results · clear Chest filter to see more)</span><span />
        </div>
      </div>

      <BruTabBar active="library" />
    </BruPhone>
  );
}

window.BruLibraryScreen = BruLibraryScreen;
