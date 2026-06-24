package dev.will.mcserver.runtime;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import org.junit.jupiter.api.Test;

final class IdleShutdownTrackerTest {
    @Test
    void waitsForGracePeriodBeforeShutdown() {
        IdleShutdownTracker tracker = new IdleShutdownTracker(Duration.ofSeconds(60));

        assertFalse(tracker.observe(0, 1_000));
        assertFalse(tracker.observe(0, 60_999));
        assertTrue(tracker.observe(0, 61_000));
    }

    @Test
    void playersResetTheIdleTimer() {
        IdleShutdownTracker tracker = new IdleShutdownTracker(Duration.ofSeconds(60));

        assertFalse(tracker.observe(0, 1_000));
        assertFalse(tracker.observe(1, 70_000));
        assertFalse(tracker.observe(0, 80_000));
        assertFalse(tracker.observe(0, 139_999));
        assertTrue(tracker.observe(0, 140_000));
    }

    @Test
    void zeroGracePeriodTriggersOnFirstEmptyObservation() {
        IdleShutdownTracker tracker = new IdleShutdownTracker(Duration.ZERO);

        assertTrue(tracker.observe(0, 1_000));
    }

    @Test
    void rejectsInvalidInputs() {
        assertThrows(IllegalArgumentException.class, () -> new IdleShutdownTracker(Duration.ofMillis(-1)));

        IdleShutdownTracker tracker = new IdleShutdownTracker(Duration.ZERO);
        assertThrows(IllegalArgumentException.class, () -> tracker.observe(-1, 1_000));
    }
}
