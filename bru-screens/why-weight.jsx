// Phase 3 · Why-this-weight + Warm-up Ramp
// Set-detail view: prescribed weight with formula, last session, percent, rounding, ramp.

function BruWhyWeightScreen() {
  return (
    <BruPhone>
      <BruHeader left="‹ Push A" center="Bench · Set 5" right="EDIT" />

      {/* Hero — recommended */}
      <div style={{ background: BRU.ink, color: BRU.paper, padding: '16px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between',
          fontSize: 10, letterSpacing: 1.5, fontWeight: 700 }}>
          <span style={{ color: BRU.signal }}>● RECOMMENDED · RPE AUTOREG</span>
          <span style={{ opacity: 0.5 }}>TOP SET</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, marginTop: 6 }}>
          <BruDisplay size={128} color={BRU.paper}>205</BruDisplay>
          <span style={{ fontFamily: BRU.display, fontSize: 26, opacity: 0.6, marginBottom: 12 }}>LB</span>
        </div>
        <div style={{ display: 'flex', borderTop: `2px solid ${BRU.paper}`, marginTop: 8 }}>
          <div style={{ flex: 1, padding: '8px 0', borderRight: `1px solid ${BRU.paper}` }}>
            <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 1.2, fontWeight: 700 }}>REPS</div>
            <BruDisplay size={32} color={BRU.paper}>×8</BruDisplay>
          </div>
          <div style={{ flex: 1, padding: '8px 0 8px 12px' }}>
            <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 1.2, fontWeight: 700 }}>RPE</div>
            <BruDisplay size={32} color={BRU.signal}>@9</BruDisplay>
          </div>
        </div>
      </div>

      {/* Why-this-weight disclosure (expanded) */}
      <BruSectionHead right="−">Why this weight</BruSectionHead>
      <div style={{ padding: '12px 16px', borderBottom: `2px solid ${BRU.ink}` }}>
        {/* Step 1 */}
        <div style={{ display: 'grid', gridTemplateColumns: '24px 1fr',
          gap: 12, alignItems: 'baseline' }}>
          <span style={{ fontFamily: BRU.display, fontSize: 22, color: BRU.signal }}>01</span>
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8,
              textTransform: 'uppercase' }}>Last session</div>
            <div style={{ fontFamily: BRU.mono, fontSize: 13, marginTop: 4 }}>
              195 × 8 @ RPE&nbsp;8.5 (May 16)
            </div>
            <div style={{ fontSize: 11, color: BRU.muted, marginTop: 2 }}>
              You had ~1.5 reps in reserve.
            </div>
          </div>
        </div>
        <div style={{ height: 8 }} />
        {/* Step 2 */}
        <div style={{ display: 'grid', gridTemplateColumns: '24px 1fr',
          gap: 12, alignItems: 'baseline' }}>
          <span style={{ fontFamily: BRU.display, fontSize: 22, color: BRU.signal }}>02</span>
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8,
              textTransform: 'uppercase' }}>Target @ RPE 9</div>
            <div style={{ fontFamily: BRU.mono, fontSize: 13, marginTop: 4 }}>
              195 × (1 − 0.04 × (9 − 8.5)) → 207 lb
            </div>
            <div style={{ fontSize: 11, color: BRU.muted, marginTop: 2 }}>
              Tuchscherer prior · calibrating (8 sets logged of 10)
            </div>
          </div>
        </div>
        <div style={{ height: 8 }} />
        {/* Step 3 */}
        <div style={{ display: 'grid', gridTemplateColumns: '24px 1fr',
          gap: 12, alignItems: 'baseline' }}>
          <span style={{ fontFamily: BRU.display, fontSize: 22, color: BRU.signal }}>03</span>
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8,
              textTransform: 'uppercase' }}>Rounded to plate ½ lb</div>
            <div style={{ fontFamily: BRU.mono, fontSize: 13, marginTop: 4 }}>
              207 → <span style={{ color: BRU.signal, fontWeight: 700 }}>205</span>
              <span style={{ color: BRU.muted }}> (45 + 25 + 10)</span>
            </div>
          </div>
        </div>

        {/* Calibration meter */}
        <div style={{ marginTop: 14, padding: 10,
          border: `1.5px solid ${BRU.ink}`, background: BRU.bg2 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between',
            fontSize: 10, fontWeight: 700, letterSpacing: 1.2 }}>
            <span>CALIBRATING · 8 / 10 SETS</span>
            <span style={{ color: BRU.signal }}>RANGE ± 5 LB</span>
          </div>
          <div style={{ marginTop: 6, height: 6, background: BRU.paper, position: 'relative' }}>
            <div style={{ position: 'absolute', inset: 0, width: '80%', background: BRU.signal }} />
          </div>
        </div>
      </div>

      {/* Warm-up ramp */}
      <BruSectionHead right="Plate ½ lb · ×2 sides">Warm-up ramp</BruSectionHead>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {[
          { n: 'W1', pct: '45%',  w: 95,  reps: 8, rpe: 4,  plates: [45, 25] },
          { n: 'W2', pct: '65%',  w: 135, reps: 6, rpe: 5,  plates: [45] },
          { n: 'W3', pct: '80%',  w: 165, reps: 4, rpe: 6,  plates: [45, 10, 5] },
          { n: 'W4', pct: '90%',  w: 185, reps: 3, rpe: 7,  plates: [45, 25] },
        ].map((s, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '36px 1fr 1fr auto',
            gap: 10, alignItems: 'center',
            padding: '10px 16px', borderBottom: `1px solid ${BRU.hair}`,
          }}>
            <span style={{ fontFamily: BRU.display, fontSize: 18, color: BRU.signal }}>{s.n}</span>
            <div>
              <BruDisplay size={22}>{s.w} <span style={{ fontSize: 10, opacity: 0.5 }}>{s.pct}</span></BruDisplay>
              <div style={{ fontFamily: BRU.mono, fontSize: 10, color: BRU.muted, marginTop: 2 }}>
                ×{s.reps} @ {s.rpe}
              </div>
            </div>
            {/* Mini plate viz */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <div style={{ width: 12, height: 3, background: BRU.muted }} />
              {s.plates.map((p, j) => (
                <div key={j} style={{
                  width: Math.max(3, p * 0.16),
                  height: 18 + p * 0.2,
                  background: BRU.ink,
                  border: `0.5px solid ${BRU.bg}`,
                }} />
              ))}
              <div style={{ flex: 1, height: 2, background: BRU.faint }} />
            </div>
            <span style={{ fontFamily: BRU.mono, fontSize: 9, color: BRU.muted, letterSpacing: 0.5 }}>
              {s.plates.join('+')}
            </span>
          </div>
        ))}
        <div style={{ padding: '10px 16px', display: 'flex',
          justifyContent: 'space-between', fontSize: 10, fontWeight: 700, letterSpacing: 1.2 }}>
          <span>WORK SETS BEGIN AT</span>
          <span>205 LB</span>
        </div>
      </div>

      <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
        <BruButton kind="ghost" size="md">Override</BruButton>
        <BruButton kind="signal" size="md">Use 205 ▸</BruButton>
      </div>
      <div style={{ height: 24, background: BRU.bg }} />
    </BruPhone>
  );
}

window.BruWhyWeightScreen = BruWhyWeightScreen;
