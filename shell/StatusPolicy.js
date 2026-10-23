.pragma library

function validFraction(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 && value <= 1;
}

function signalLevel(value) {
    return validFraction(value) ? Math.ceil(value * 4) : -1;
}

function cellularStrength(cellular) {
    if (!cellular || !cellular.available || !cellular.enabled || !cellular.registered
            || typeof cellular.signal !== "number" || !isFinite(cellular.signal)
            || cellular.signal < 0 || cellular.signal > 100)
        return -1;
    return cellular.signal / 100;
}
