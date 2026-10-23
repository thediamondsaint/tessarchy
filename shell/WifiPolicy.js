.pragma library

// Restore the live shell's native connected-network measurement. Never invent
// a signal for absent hardware, disconnected devices or unavailable readings.
function signalStrength(device) {
    if (!device || !device.networks) return -1;
    const networks = device.networks.values;
    for (let i = 0; i < networks.length; ++i) {
        if (networks[i].connected) {
            const strength = networks[i].signalStrength;
            return typeof strength === "number" && isFinite(strength)
                && strength >= 0 && strength <= 1 ? strength : -1;
        }
    }
    return -1;
}
