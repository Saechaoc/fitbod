// Brutalist theme — shared by all Fitbod screens.
// Hard edges · condensed display · monochrome with signal accents.

window.BRU = {
  bg: '#F0EDE5', // raw paper
  bg2: '#E8E4D9',
  ink: '#0A0A0A',
  ink2: '#1C1C1A',
  paper: '#FFFFFF',
  signal: '#FF4D2E',
  green: '#1A5F3F',
  amber: '#D89A1A',
  muted: 'rgba(10,10,10,0.55)',
  faint: 'rgba(10,10,10,0.25)',
  hair: 'rgba(10,10,10,0.12)',
  font: '"Space Grotesk", "Geist", system-ui, sans-serif',
  display: '"Bebas Neue", "Oswald", "Archivo Narrow", "Space Grotesk", sans-serif',
  mono: '"JetBrains Mono", "IBM Plex Mono", ui-monospace, monospace'
};

// ─────────────────────────────────────────────────────────────
// Phone shell — every screen renders inside this.
// ─────────────────────────────────────────────────────────────
function BruPhone({ children, dark = false, time = '9:41', right = null }) {
  const ink = dark ? BRU.bg : BRU.ink;
  return (
    <div style={{
      width: '100%', height: '100%',
      background: dark ? BRU.ink : BRU.bg, color: ink,
      fontFamily: BRU.font, position: 'relative',
      padding: '54px 0 0', boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column', overflow: 'hidden'
    }}>
      {/* status */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, zIndex: 1,
        display: 'flex', justifyContent: 'space-between',
        padding: '18px 24px 0', fontSize: 13, fontWeight: 700,
        color: ink, whiteSpace: 'nowrap' }}>
        <span>{time}</span>
        {right ?? <span></span>}
      </div>
      {children}
    </div>);

}

// Tab bar — bottom nav primitive (Today · Program · Progress · Library)
function BruTabBar({ active = 'today', onChange }) {
  const tabs = [
  { id: 'today', label: 'TODAY' },
  { id: 'program', label: 'PROGRAM' },
  { id: 'progress', label: 'PROGRESS' },
  { id: 'library', label: 'LIBRARY' }];

  return (
    <div style={{
      borderTop: `2px solid ${BRU.ink}`, background: BRU.bg,
      display: 'flex', padding: '8px 0 24px'
    }}>
      {tabs.map((t) =>
      <button key={t.id} onClick={() => onChange?.(t.id)}
      style={{
        flex: 1, padding: '8px 0', border: 'none', cursor: 'pointer',
        background: t.id === active ? BRU.ink : 'transparent',
        color: t.id === active ? BRU.paper : BRU.ink,
        fontFamily: BRU.font, fontSize: 10, fontWeight: 700,
        letterSpacing: 1.5, textTransform: 'uppercase'
      }}>
          {t.label}
        </button>
      )}
    </div>);

}

// Header slab — borderTop + borderBottom + 3-cell flex
function BruHeader({ left, center, right }) {
  return (
    <div style={{
      borderTop: `2px solid ${BRU.ink}`, borderBottom: `2px solid ${BRU.ink}`,
      padding: '8px 16px', display: 'flex', justifyContent: 'space-between',
      fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1.2,
      whiteSpace: 'nowrap', alignItems: 'center', gap: 12
    }}>
      <span>{left}</span>
      {center && <span>{center}</span>}
      {right && <span>{right}</span>}
    </div>);

}

// Display-typo helper
function BruDisplay({ children, size = 60, color, style }) {
  return (
    <div style={{
      fontFamily: BRU.display, fontSize: size,
      lineHeight: 0.86, letterSpacing: 0.5,
      textTransform: 'uppercase', fontWeight: 400,
      color: color || BRU.ink, fontVariantNumeric: 'tabular-nums',
      ...style
    }}>{children}</div>);

}

// Tag / chip / pill — brutalist version is a bordered uppercase box
function BruChip({ children, fill = false, color = BRU.ink, style }) {
  return (
    <span style={{
      display: 'inline-block', padding: '3px 8px',
      border: `1.5px solid ${color}`,
      background: fill ? color : 'transparent',
      color: fill ? BRU.paper : color,
      fontSize: 9, fontWeight: 700, letterSpacing: 1.2,
      textTransform: 'uppercase', whiteSpace: 'nowrap',
      ...style
    }}>{children}</span>);

}

// Big block button
function BruButton({ children, onClick, kind = 'primary', size = 'lg', style }) {
  const bg = kind === 'primary' ? BRU.ink :
  kind === 'signal' ? BRU.signal :
  kind === 'ghost' ? 'transparent' : BRU.ink;
  const fg = kind === 'ghost' ? BRU.ink : BRU.paper;
  const border = kind === 'ghost' ? `2px solid ${BRU.ink}` : 'none';
  const padding = size === 'lg' ? '16px 0' : size === 'md' ? '12px 0' : '8px 0';
  const fontSize = size === 'lg' ? 22 : size === 'md' ? 14 : 11;
  return (
    <button onClick={onClick} style={{
      background: bg, color: fg, border, borderRadius: 0,
      padding, fontFamily: size === 'lg' ? BRU.display : BRU.font,
      fontSize, fontWeight: size === 'lg' ? 400 : 700,
      letterSpacing: size === 'lg' ? 1.5 : 1.5,
      textTransform: 'uppercase', cursor: 'pointer',
      width: '100%', boxSizing: 'border-box', whiteSpace: 'nowrap',
      ...style
    }}>{children}</button>);

}

// Numerical readout: label + value, stacked compact
function BruReadout({ label, value, color, big = false }) {
  return (
    <div>
      <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1.5,
        color: BRU.muted, textTransform: 'uppercase' }}>{label}</div>
      <div style={{
        fontFamily: BRU.display, fontSize: big ? 36 : 22,
        lineHeight: 1, fontVariantNumeric: 'tabular-nums',
        color: color || BRU.ink, marginTop: 2
      }}>{value}</div>
    </div>);

}

// Row primitive — left | right with optional hairline below
function BruRow({ children, border = true, padding = '12px 16px', onClick, style }) {
  return (
    <div onClick={onClick} style={{
      padding,
      borderBottom: border ? `1px solid ${BRU.hair}` : 'none',
      display: 'flex', alignItems: 'center', gap: 12,
      cursor: onClick ? 'pointer' : 'default',
      ...style
    }}>{children}</div>);

}

// Section header — uppercase mono-feel with rule
function BruSectionHead({ children, right }) {
  return (
    <div style={{
      borderTop: `2px solid ${BRU.ink}`, borderBottom: `1px solid ${BRU.ink}`,
      padding: '6px 16px', display: 'flex', justifyContent: 'space-between',
      fontSize: 10, fontWeight: 700, letterSpacing: 1.5, textTransform: 'uppercase',
      whiteSpace: 'nowrap'
    }}>
      <span>{children}</span>
      {right && <span style={{ color: BRU.muted }}>{right}</span>}
    </div>);

}

// Sparkline (mini line chart)
function BruSpark({ values, w = 80, h = 24, color, fill = false }) {
  const c = color || BRU.ink;
  const min = Math.min(...values),max = Math.max(...values);
  const pad = (max - min) * 0.15 || 1;
  const lo = min - pad,hi = max + pad;
  const xs = values.map((v, i) => i / (values.length - 1) * w);
  const ys = values.map((v) => h - (v - lo) / (hi - lo) * h);
  const pts = xs.map((x, i) => `${x.toFixed(1)},${ys[i].toFixed(1)}`).join(' ');
  const area = `${xs[0]},${h} ${pts} ${xs[xs.length - 1]},${h}`;
  return (
    <svg width={w} height={h} style={{ display: 'block' }}>
      {fill && <polygon points={area} fill={c} fillOpacity={0.12} />}
      <polyline points={pts} fill="none" stroke={c} strokeWidth="1.5" />
      {values.map((_, i) =>
      <rect key={i} x={xs[i] - 1} y={ys[i] - 1} width={2} height={2} fill={c} />
      )}
    </svg>);

}

Object.assign(window, {
  BruPhone, BruTabBar, BruHeader, BruDisplay, BruChip, BruButton,
  BruReadout, BruRow, BruSectionHead, BruSpark
});

// ─────────────────────────────────────────────────────────────
// Modal primitives — brutalist takes on iOS sheet / alert / context menu
// ─────────────────────────────────────────────────────────────

// Dimmed backdrop that sits under modals (covers everything below status bar)
function BruDim({ children, opacity = 0.55 }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `rgba(10,10,10,${opacity})`,
      zIndex: 10, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end'
    }}>{children}</div>);

}

// Bottom sheet — squared corners, 2-px frame, full-width inside the phone
function BruSheet({ title, subtitle, children, footer, height }) {
  return (
    <div style={{
      background: BRU.bg, color: BRU.ink,
      borderTop: `4px solid ${BRU.ink}`,
      maxHeight: height || '78%', display: 'flex', flexDirection: 'column',
      animation: 'sheetIn 240ms cubic-bezier(.2,.6,.2,1)'
    }}>
      {/* Sheet handle bar (brutalist version is a small black tab) */}
      <div style={{ display: 'flex', justifyContent: 'center', padding: '6px 0 4px' }}>
        <div style={{ width: 48, height: 4, background: BRU.ink }} />
      </div>
      <div style={{ padding: '6px 16px 12px', borderBottom: `2px solid ${BRU.ink}` }}>
        <div style={{ fontSize: 9, color: BRU.muted, letterSpacing: 1.5, fontWeight: 700 }}>
          {subtitle?.toUpperCase()}
        </div>
        <div style={{ fontFamily: BRU.display, fontSize: 28, lineHeight: 1,
          letterSpacing: 0.5, marginTop: 4, textTransform: 'uppercase' }}>
          {title}
        </div>
      </div>
      <div style={{ flex: 1, overflow: 'auto' }}>{children}</div>
      {footer &&
      <div style={{ borderTop: `2px solid ${BRU.ink}`, display: 'flex' }}>
          {footer}
        </div>
      }
    </div>);

}

// Centered alert — bordered box, tab top, two-button row
function BruAlert({ kind = 'default', title, body, primary, secondary, blocked = false }) {
  const accent = kind === 'destructive' ? BRU.signal : BRU.ink;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 20,
      background: 'rgba(10,10,10,0.55)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '0 24px'
    }}>
      <div style={{
        width: '100%', background: BRU.bg, color: BRU.ink,
        border: `3px solid ${BRU.ink}`
      }}>
        {/* Tab top */}
        <div style={{
          background: accent, color: BRU.paper, padding: '6px 12px',
          fontSize: 10, fontWeight: 700, letterSpacing: 1.5,
          display: 'flex', justifyContent: 'space-between'
        }}>
          <span>{kind === 'destructive' ? '▲ CONFIRM' : '● DIALOG'}</span>
          <span>{blocked ? 'BLOCKED' : ''}</span>
        </div>
        <div style={{ padding: '14px 16px 8px' }}>
          <div style={{ fontFamily: BRU.display, fontSize: 24, lineHeight: 1.05,
            letterSpacing: 0.5, textTransform: 'uppercase' }}>
            {title}
          </div>
          <div style={{ fontSize: 13, lineHeight: 1.4, marginTop: 8, color: BRU.ink2 }}>
            {body}
          </div>
        </div>
        <div style={{ display: 'flex', borderTop: `2px solid ${BRU.ink}` }}>
          <button style={{
            flex: 1, padding: '14px 0', border: 'none', cursor: 'pointer',
            background: 'transparent', borderRight: `2px solid ${BRU.ink}`,
            fontFamily: BRU.font, fontSize: 12, fontWeight: 700, letterSpacing: 1.5,
            textTransform: 'uppercase', color: BRU.ink
          }}>{secondary || 'Cancel'}</button>
          <button style={{
            flex: 1, padding: '14px 0', border: 'none', cursor: 'pointer',
            background: blocked ? BRU.faint : accent,
            color: blocked ? BRU.muted : BRU.paper,
            fontFamily: BRU.font, fontSize: 12, fontWeight: 700, letterSpacing: 1.5,
            textTransform: 'uppercase'
          }}>{primary}</button>
        </div>
      </div>
    </div>);

}

// Floating menu (anchored — for "+ NEW" menus and context menus)
function BruMenu({ items, style }) {
  return (
    <div style={{
      background: BRU.paper, border: `2px solid ${BRU.ink}`,
      boxShadow: `4px 4px 0 ${BRU.ink}`,
      minWidth: 200, zIndex: 30, ...style
    }}>
      {items.map((it, i) =>
      <div key={i} style={{
        padding: '11px 14px', display: 'flex', alignItems: 'center',
        justifyContent: 'space-between', gap: 12,
        borderBottom: i < items.length - 1 ? `1px solid ${BRU.hair}` : 'none',
        background: it.destructive ? `${BRU.signal}10` : 'transparent',
        cursor: 'pointer'
      }}>
          <span style={{ fontSize: 13, fontWeight: 600,
          color: it.destructive ? BRU.signal : it.disabled ? BRU.muted : BRU.ink,
          letterSpacing: 0.2
        }}>{it.label}</span>
          {it.kbd && <span style={{ fontFamily: BRU.mono, fontSize: 10,
          color: BRU.muted, letterSpacing: 1 }}>{it.kbd}</span>}
        </div>
      )}
    </div>);

}

Object.assign(window, { BruDim, BruSheet, BruAlert, BruMenu });