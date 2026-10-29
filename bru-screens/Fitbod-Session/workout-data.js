// Shared workout data + session state hook
// Block: Upper Hypertrophy · Week 3/5 · Push A

window.WORKOUT = {
  block: 'Upper Hypertrophy',
  blockWeek: 3,
  blockTotal: 5,
  day: 'Push A',
  dayIdx: 1, dayTotal: 4,
  startedAt: '10:42',
  elapsed: '38:14',
  exercises: [
    {
      id: 'bench',
      name: 'Barbell Bench Press',
      muscle: 'Chest',
      equipment: 'Barbell',
      e1rm: 248,
      e1rmDelta: +4,
      lastSession: '195 × 8 @ 8.5',
      sets: [
        { kind: 'warmup',  weight:  95, reps: 8,  rpe: 4,   done: true,  intent: 'Warm-up',  actualReps: 8 },
        { kind: 'warmup',  weight: 135, reps: 6,  rpe: 5,   done: true,  intent: 'Warm-up',  actualReps: 6 },
        { kind: 'working', weight: 165, reps: 8,  rpe: 7,   done: true,  intent: 'Build',    actualReps: 8 },
        { kind: 'working', weight: 185, reps: 8,  rpe: 8,   done: true,  intent: 'Build',    actualReps: 8 },
        { kind: 'top',     weight: 205, reps: 8,  rpe: 9,   done: false, intent: 'Top set',  actualReps: null, current: true },
        { kind: 'backoff', weight: 175, reps: 10, rpe: 8,   done: false, intent: 'Back-off', actualReps: null },
      ],
    },
    { id: 'incline', name: 'Incline DB Press', muscle: 'Chest', equipment: 'Dumbbell',
      sets: [{ kind:'working', weight: 65, reps: 10, rpe: 8 }, { kind:'working', weight: 65, reps: 10, rpe: 8 }, { kind:'working', weight: 65, reps: 10, rpe: 8 }] },
    { id: 'fly', name: 'Cable Fly', muscle: 'Chest', equipment: 'Cable',
      sets: [{ kind:'working', weight: 30, reps: 12, rpe: 9 }, { kind:'working', weight: 30, reps: 12, rpe: 9 }, { kind:'working', weight: 30, reps: 12, rpe: 9 }] },
    { id: 'pushdown', name: 'Tricep Pushdown', muscle: 'Triceps', equipment: 'Cable',
      sets: [{ kind:'working', weight: 70, reps: 12, rpe: 9 }, { kind:'working', weight: 70, reps: 12, rpe: 9 }, { kind:'working', weight: 70, reps: 12, rpe: 9 }, { kind:'working', weight: 70, reps: 12, rpe: 9 }] },
    { id: 'oh', name: 'OH Tricep Ext', muscle: 'Triceps', equipment: 'Cable', tag: 'Cluster',
      sets: [{ kind:'cluster', weight: 50, reps: 15, rpe: 9 }, { kind:'cluster', weight: 50, reps: 15, rpe: 9 }, { kind:'cluster', weight: 50, reps: 15, rpe: 9 }] },
  ],
};

// Plate math for a 45lb bar, lb plates: 45, 25, 10, 5, 2.5
window.platesFor = function(target, bar = 45) {
  const sides = (target - bar) / 2;
  const opts = [45, 25, 10, 5, 2.5];
  const out = [];
  let remain = sides;
  for (const p of opts) {
    while (remain >= p - 1e-9) { out.push(p); remain -= p; }
  }
  return out;
};

// Useful for "Last 4 sessions" sparklines
window.E1RM_HISTORY = [232, 236, 238, 244, 248];
