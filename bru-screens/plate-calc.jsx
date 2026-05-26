// Phase 3 · Plate Calculator + Inventory
// Stack viz · inventory editor · bar selection

function BruPlateCalcScreen() {
  const target = 205;
  const bar = 45;
  const platesPerSide = window.platesFor ? window.platesFor(target, bar) : [45, 25, 10];

  // Inventory (per-equipment plate counts, per side)
  const inv = [
    { weight: 45,   count: 4, color: BRU.ink },
    { weight: 35,   count: 0, color: BRU.muted },
    { weight: 25,   count: 4, color: BRU.signal },
    { weight: 10,   count: 4, color: BRU.green },
    { weight: 5,    count: 4, color: BRU.amber },
    { weight: 2.5,  count: 2, color: BRU.muted },
  ];

  const totalPlateWeight = platesPerSide.reduce((a, b) => a + b, 0) * 2;
  return (
    <BruPhone>
      <BruHeader left="‹ Push A" center="Plate calculator" right="•••" />

      {/* Target display */}
      <div style={{ padding: '14px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          alignItems: 'baseline' }}>
          <span style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700 }}>TARGET</span>
          <span style={{ fontSize: 10, letterSpacing: 1.2, color: BRU.muted }}>
            BAR&nbsp;45 + PLATES&nbsp;{totalPlateWeight}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
          <BruDisplay size={96}>{target}</BruDisplay>
          <span style={{ fontFamily: BRU.display, fontSize: 22, color: BRU.muted }}>LB</span>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 4 }}>
            <BruChip>−5</BruChip>
            <BruChip>−2.5</BruChip>
            <BruChip>+2.5</BruChip>
            <BruChip>+5</BruChip>
          </div>
        </div>
      </div>

      {/* PLATE STACK · big viz */}
      <div style={{ padding: '20px 16px', borderBottom: `2px solid ${BRU.ink}`,
        background: BRU.bg2 }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5,
          marginBottom: 12 }}>PER SIDE</div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center',
          gap: 2, position: 'relative' }}>
          {/* sleeve */}
          <div style={{ width: 30, height: 16, background: BRU.muted,
            borderRight: `2px solid ${BRU.ink}` }} />
          {platesPerSide.map((p, i) => {
            const h = 40 + p * 0.8;
            const w = Math.max(8, p * 0.4);
            return (
              <div key={i} style={{
                width: w, height: h, background: BRU.ink,
                border: `1px solid ${BRU.bg2}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <span style={{ color: BRU.paper, fontFamily: BRU.display,
                  fontSize: 12, transform: 'rotate(-90deg)', letterSpacing: 0.5,
                  whiteSpace: 'nowrap' }}>{p}</span>
              </div>
            );
          })}
          {/* end cap */}
          <div style={{ width: 8, height: 60, background: BRU.muted,
            border: `2px solid ${BRU.ink}`, marginLeft: 4 }} />
        </div>
        <div style={{ marginTop: 12, display: 'flex', justifyContent: 'center', gap: 12,
          fontFamily: BRU.mono, fontSize: 11 }}>
          {platesPerSide.map((p, i) => (
            <span key={i} style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <span style={{ width: 8, height: 8, background: BRU.ink }} />
              {p}
            </span>
          ))}
        </div>
      </div>

      {/* Equipment + bar */}
      <BruSectionHead right="TAP TO CHANGE">Equipment</BruSectionHead>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr',
        borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ padding: '10px 16px', borderRight: `1px solid ${BRU.hair}` }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>BAR</div>
          <BruDisplay size={20}>Olympic · 45 lb</BruDisplay>
        </div>
        <div style={{ padding: '10px 16px' }}>
          <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.2, fontWeight: 700 }}>INVENTORY</div>
          <BruDisplay size={20}>Home gym</BruDisplay>
        </div>
      </div>

      {/* Plate inventory */}
      <BruSectionHead right="PER SIDE">Plates available</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {inv.map((p, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '90px 1fr 80px',
            gap: 10, alignItems: 'center',
            padding: '10px 16px', borderBottom: `1px solid ${BRU.hair}`,
            opacity: p.count === 0 ? 0.4 : 1,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 16, height: 28, background: BRU.ink }} />
              <BruDisplay size={20}>{p.weight}</BruDisplay>
            </div>
            {/* Tally marks */}
            <div style={{ display: 'flex', gap: 3 }}>
              {Array.from({ length: 4 }).map((_, j) => (
                <div key={j} style={{
                  flex: 1, height: 20, border: `1.5px solid ${BRU.ink}`,
                  background: j < p.count ? BRU.ink : 'transparent',
                }} />
              ))}
            </div>
            <div style={{ textAlign: 'right' }}>
              <span style={{ fontFamily: BRU.mono, fontSize: 11, fontWeight: 600 }}>
                {p.count > 0 ? `×${p.count}` : 'NONE'}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Footer */}
      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md">Save inventory</BruButton>
        <BruButton kind="primary" size="md">Done ▸</BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruPlateCalcScreen = BruPlateCalcScreen;
