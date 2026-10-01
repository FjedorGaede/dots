.pragma library
// Network list helpers

// Connected networks first, then strongest signal first.
function byConnectionThenSignal(a, b) {
    if (!!a?.connected !== !!b?.connected) return a?.connected ? -1 : 1;
    return (b?.signalStrength ?? 0) - (a?.signalStrength ?? 0);
}
