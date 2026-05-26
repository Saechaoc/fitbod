// Phase 5 · Muscle Heatmap · stylized block-anatomy front/back, tappable
// Avoids hand-drawn organic silhouettes — every region is a rectangle.

function BruHeatmapScreen() {
  // intensity 0–4 maps to fill saturation
  const fill = (i, alarm) => {
    if (i === 0) return BRU.bg2;
    if (alarm) return BRU.signal;
    const palette = ['transparent', '#0A0A0A33', '#0A0A0A66', '#0A0A0A99', BRU.ink];
    return palette[Math.min(4, i)];
  };

  // Each muscle is a rect with grid coords. Symmetrical pairs.
  const front = [
    // Head + neck
    { x: 4, y: 0, w: 2, h: 1, name: 'NECK',  i: 1 },
    // Shoulders
    { x: 1, y: 1, w: 2, h: 1, name: 'DELT',  i: 3 },
    { x: 7, y: 1, w: 2, h: 1, name: 'DELT',  i: 3 },
    // Chest (big block, split into 2)
    { x: 3, y: 1, w: 2, h: 2, name: 'CHEST L', i: 3 },
    { x: 5, y: 1, w: 2, h: 2, name: 'CHEST R', i: 3 },
    // Biceps
    { x: 1, y: 2, w: 2, h: 2, name: 'BICEP', i: 1 },
    { x: 7, y: 2, w: 2, h: 2, name: 'BICEP', i: 1 },
    // Abs
    { x: 3, y: 3, w: 2, h: 3, name: 'ABS L', i: 1 },
    { x: 5, y: 3, w: 2, h: 3, name: 'ABS R', i: 1 },
    // Forearms
    { x: 1, y: 4, w: 2, h: 2, name: 'FORE', i: 0 },
    { x: 7, y: 4, w: 2, h: 2, name: 'FORE', i: 0 },
    // Quads
    { x: 3, y: 6, w: 2, h: 3, name: 'QUAD', i: 1, warn: true },
    { x: 5, y: 6, w: 2, h: 3, name: 'QUAD', i: 1, warn: true },
    // Calves
    { x: 3, y: 9, w: 2, h: 2, name: 'CALF', i: 0 },
    { x: 5, y: 9, w: 2, h: 2, name: 'CALF', i: 0 },
  ];

  const back = [
    { x: 4, y: 0, w: 2, h: 1, name: 'NECK',  i: 1 },
    // Traps
    { x: 3, y: 1, w: 4, h: 1, name: 'TRAPS', i: 2 },
    // Rear delts
    { x: 1, y: 1, w: 2, h: 1, name: 'R.DELT', i: 2 },
    { x: 7, y: 1, w: 2, h: 1, name: 'R.DELT', i: 2 },
    // Upper back
    { x: 3, y: 2, w: 4, h: 1, name: 'UPPER BACK', i: 3 },
    // Lats
    { x: 1, y: 2, w: 2, h: 3, name: 'LAT', i: 3 },
    { x: 7, y: 2, w: 2, h: 3, name: 'LAT', i: 3 },
    // Triceps
    { x: 0, y: 2, w: 1, h: 2, name: 'TRI', i: 4, alarm: true },
    { x: 9, y: 2, w: 1, h: 2, name: 'TRI', i: 4, alarm: true },
    // Lower back
    { x: 3, y: 5, w: 4, h: 1, name: 'LOWER BACK', i: 1 },
    // Glutes
    { x: 3, y: 6, w: 2, h: 2, name: 'GLUTE', i: 2 },
    { x: 5, y: 6, w: 2, h: 2, name: 'GLUTE', i: 2 },
    // Hamstrings
    { x: 3, y: 8, w: 2, h: 2, name: 'HAM', i: 0 },
    { x: 5, y: 8, w: 2, h: 2, name: 'HAM', i: 0 },
    // Calves
    { x: 3, y: 10, w: 2, h: 1, name: 'CALF', i: 0 },
    { x: 5, y: 10, w: 2, h: 1, name: 'CALF', i: 0 },
  ];

  const renderBody = (rects, label) => {
    const cell = 14;
    const cols = 10, rows = 12;
    return (
      <div>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.5,
          marginBottom: 8, textAlign: 'center' }}>
          {label}
        </div>
        <div style={{
          width: cols * cell, height: rows * cell,
          position: 'relative', border: `2px solid ${BRU.ink}`,
          background: BRU.bg2, margin: '0 auto',
          backgroundImage: `linear-gradient(${BRU.hair} 1px, transparent 1px), linear-gradient(90deg, ${BRU.hair} 1px, transparent 1px)`,
          backgroundSize: `${cell}px ${cell}px`,
        }}>
          {rects.map((r, i) => (
            <div key={i} style={{
              position: 'absolute',
              left: r.x * cell, top: r.y * cell,
              width: r.w * cell - 1, height: r.h * cell - 1,
              background: r.alarm ? BRU.signal : r.warn ? BRU.amber : fill(r.i),
              border: `1px solid ${BRU.ink}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 7, fontWeight: 700, letterSpacing: 0.4,
              color: r.i >= 3 || r.alarm ? BRU.paper : BRU.ink,
              overflow: 'hidden',
            }}>{r.name}</div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <BruPhone>
      <BruHeader left="‹" center="Muscle heatmap" right="W3 / 5" />

      {/* Hero */}
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '14px 16px',
        display: 'flex', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 10, letterSpacing: 1.5, fontWeight: 700, opacity: 0.6 }}>
            WEEK · SUM STIMULUS
          </div>
          <BruDisplay size={42} color={BRU.paper}>85 SETS</BruDisplay>
          <div style={{ fontSize: 11, opacity: 0.7, marginTop: 4, letterSpacing: 0.5 }}>
            8 muscles · 4 in MAV · 2 alerts
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <BruChip color={BRU.paper} style={{ background: 'transparent', borderColor: BRU.paper }}>
            VS LAST WK +12
          </BruChip>
        </div>
      </div>

      {/* Bodies */}
      <div style={{ padding: '20px 16px', display: 'flex',
        gap: 20, justifyContent: 'center', borderBottom: `2px solid ${BRU.ink}` }}>
        {renderBody(front, 'FRONT')}
        {renderBody(back, 'BACK')}
      </div>

      {/* Tappable list */}
      <BruSectionHead right="TAP TO DRILL">By muscle</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { name: 'TRICEPS', sets: 19, freq: '3 / wk', state: 'NEAR MRV — DELOAD', alarm: true },
          { name: 'CHEST',   sets: 16, freq: '2 / wk', state: 'IN MAV · ADD A SET', good: true },
          { name: 'LATS',    sets: 14, freq: '2 / wk', state: 'IN MAV · HOLD' },
          { name: 'FRONT DELTS', sets: 12, freq: '3 / wk', state: 'IN MAV · HOLD' },
          { name: 'GLUTES',  sets: 10, freq: '1 / wk', state: 'IN MAV · HOLD' },
          { name: 'BICEPS',  sets: 8,  freq: '2 / wk', state: 'AT MEV · ADD A SET', good: true },
          { name: 'QUADS',   sets: 6,  freq: '1 / wk', state: 'UNDER MEV', warn: true },
          { name: 'HAMSTRINGS', sets: 0, freq: '0 / wk', state: 'NOT TRAINED', off: true },
        ].map((m, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '90px 1fr 90px',
            gap: 10, alignItems: 'center',
            padding: '10px 16px', borderBottom: `1px solid ${BRU.hair}`,
            opacity: m.off ? 0.5 : 1,
          }}>
            <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: 1.2 }}>{m.name}</span>
            <div>
              <BruDisplay size={20}>{m.sets} SETS</BruDisplay>
              <div style={{ fontFamily: BRU.mono, fontSize: 9, color: BRU.muted, marginTop: 2 }}>
                FREQ {m.freq}
              </div>
            </div>
            <BruChip
              color={m.alarm ? BRU.signal : m.warn ? BRU.amber : m.good ? BRU.green : BRU.ink}
              fill={m.alarm || m.warn}>
              {m.state.split(' · ')[0]}
            </BruChip>
          </div>
        ))}
      </div>

      <BruTabBar active="progress" />
    </BruPhone>
  );
}

window.BruHeatmapScreen = BruHeatmapScreen;
