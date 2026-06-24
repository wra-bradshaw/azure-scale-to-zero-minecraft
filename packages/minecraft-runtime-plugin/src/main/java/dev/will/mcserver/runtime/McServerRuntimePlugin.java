package dev.will.mcserver.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import org.bukkit.Bukkit;
import org.bukkit.World;
import org.bukkit.plugin.java.JavaPlugin;

public final class McServerRuntimePlugin extends JavaPlugin {
    private static final String MARKER_FILE = ".minecraft-idle-shutdown-requested";

    private IdleShutdownTracker idleShutdownTracker;
    private Path markerPath;
    private boolean shutdownRequested;

    @Override
    public void onEnable() {
        Duration gracePeriod = readDurationSeconds("SHUTDOWN_GRACE_SECONDS", 900);
        Duration pollInterval = readDurationSeconds("POLL_SECONDS", 30);
        Path dataDir = Path.of(readEnv("MC_DATA_DIR", "/srv/minecraft"));

        idleShutdownTracker = new IdleShutdownTracker(gracePeriod);
        markerPath = dataDir.resolve(MARKER_FILE);

        long pollTicks = Math.max(1L, pollInterval.toSeconds() * 20L);
        Bukkit.getScheduler().runTaskTimer(this, this::pollIdleShutdown, pollTicks, pollTicks);

        getLogger().info(
                "Idle shutdown enabled: grace=" + gracePeriod.toSeconds()
                        + "s poll=" + pollInterval.toSeconds()
                        + "s marker=" + markerPath);
    }

    private void pollIdleShutdown() {
        if (shutdownRequested) {
            return;
        }

        int onlinePlayers = Bukkit.getOnlinePlayers().size();
        if (!idleShutdownTracker.observe(onlinePlayers, System.currentTimeMillis())) {
            return;
        }

        shutdownRequested = true;
        getLogger().info("Server has been empty for the shutdown grace period; saving worlds and stopping.");

        for (World world : Bukkit.getWorlds()) {
            world.save();
        }

        try {
            Files.createDirectories(markerPath.getParent());
            Files.writeString(markerPath, "requested_at=" + Instant.now() + System.lineSeparator());
        } catch (IOException e) {
            getLogger().severe("Could not write idle shutdown marker " + markerPath + ": " + e.getMessage());
            shutdownRequested = false;
            return;
        }

        Bukkit.shutdown();
    }

    private static String readEnv(String name, String defaultValue) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            return defaultValue;
        }
        return value;
    }

    private Duration readDurationSeconds(String name, long defaultSeconds) {
        String value = readEnv(name, Long.toString(defaultSeconds));
        try {
            long seconds = Long.parseLong(value);
            if (seconds < 0) {
                throw new NumberFormatException("negative duration");
            }
            return Duration.ofSeconds(seconds);
        } catch (NumberFormatException e) {
            getLogger().warning("Invalid " + name + "=" + value + "; using " + defaultSeconds + " seconds.");
            return Duration.ofSeconds(defaultSeconds);
        }
    }
}
