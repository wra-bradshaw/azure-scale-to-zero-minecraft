package dev.will.mcserver.runtime;

import java.time.Duration;
import java.util.Objects;

final class IdleShutdownTracker {
    private final Duration gracePeriod;
    private Long emptySinceMillis;

    IdleShutdownTracker(Duration gracePeriod) {
        if (gracePeriod.isNegative()) {
            throw new IllegalArgumentException("gracePeriod must not be negative");
        }
        this.gracePeriod = Objects.requireNonNull(gracePeriod, "gracePeriod");
    }

    boolean observe(int onlinePlayers, long nowMillis) {
        if (onlinePlayers < 0) {
            throw new IllegalArgumentException("onlinePlayers must not be negative");
        }

        if (onlinePlayers > 0) {
            emptySinceMillis = null;
            return false;
        }

        if (emptySinceMillis == null) {
            emptySinceMillis = nowMillis;
        }

        return nowMillis - emptySinceMillis >= gracePeriod.toMillis();
    }
}
