// useSession — interactive session state shared by all variants.
// Each variant instantiates its own to stay independent.

function useSession(initial = window.WORKOUT) {
  // We deep-clone so multiple variants don't share mutations.
  const [workout] = React.useState(() => JSON.parse(JSON.stringify(initial)));
  const [exIdx, setExIdx] = React.useState(0);
  const [setIdx, setSetIdx] = React.useState(() => {
    const ex = initial.exercises[0];
    const i = ex.sets.findIndex(s => !s.done);
    return i >= 0 ? i : 0;
  });
  const [resting, setResting] = React.useState(false);
  const [restRemaining, setRestRemaining] = React.useState(0);
  const [restTotal, setRestTotal] = React.useState(180);
  const [logs, setLogs] = React.useState([]); // recent confirmations for toasts

  // Tick rest timer
  React.useEffect(() => {
    if (!resting) return;
    const id = setInterval(() => {
      setRestRemaining(r => {
        if (r <= 1) { clearInterval(id); setResting(false); return 0; }
        return r - 1;
      });
    }, 1000);
    return () => clearInterval(id);
  }, [resting]);

  const exercise = workout.exercises[exIdx];
  const currentSet = exercise.sets[setIdx];
  const completedCount = exercise.sets.filter(s => s.done).length;
  const totalSets = exercise.sets.length;

  // Per-exercise rest defaults: top sets get longer.
  function restForKind(kind) {
    if (kind === 'top') return 240;
    if (kind === 'backoff') return 180;
    if (kind === 'warmup') return 60;
    if (kind === 'cluster') return 20;
    return 150;
  }

  function logSet(opts = {}) {
    const { reps = currentSet.reps, rpe = currentSet.rpe } = opts;
    currentSet.done = true;
    currentSet.actualReps = reps;
    currentSet.actualRpe = rpe;
    delete currentSet.current;

    const next = exercise.sets.findIndex((s, i) => i > setIdx && !s.done);
    if (next >= 0) {
      exercise.sets[next].current = true;
      setSetIdx(next);
    } else if (exIdx + 1 < workout.exercises.length) {
      // Advance to next exercise
      setTimeout(() => {
        setExIdx(exIdx + 1);
        setSetIdx(0);
      }, 800);
    }

    const rest = restForKind(currentSet.kind);
    setRestTotal(rest);
    setRestRemaining(rest);
    setResting(true);
    setLogs(l => [{ id: Date.now(), text: `Logged ${currentSet.weight}×${reps} @ RPE ${rpe}` }, ...l].slice(0, 3));
  }

  function skipRest() {
    setResting(false);
    setRestRemaining(0);
  }

  function addRest(seconds) {
    setRestRemaining(r => r + seconds);
    setRestTotal(t => t + seconds);
  }

  function goToExercise(i) {
    if (i >= 0 && i < workout.exercises.length) {
      setExIdx(i);
      const ex = workout.exercises[i];
      const idx = ex.sets.findIndex(s => !s.done);
      setSetIdx(idx >= 0 ? idx : 0);
    }
  }

  return {
    workout, exercise, currentSet, exIdx, setIdx,
    completedCount, totalSets,
    resting, restRemaining, restTotal,
    logSet, skipRest, addRest, goToExercise,
  };
}

window.useSession = useSession;
