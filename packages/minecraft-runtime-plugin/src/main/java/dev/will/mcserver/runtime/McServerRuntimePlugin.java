package dev.will.mcserver.runtime;

import java.time.Duration;
import net.kyori.adventure.text.Component;
import org.bukkit.Bukkit;
import org.bukkit.World;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.AsyncPlayerPreLoginEvent;
import org.bukkit.event.server.ServerListPingEvent;
import org.bukkit.plugin.java.JavaPlugin;

public final class McServerRuntimePlugin extends JavaPlugin implements Listener {
  private static final String DRAINING_STATUS_MARKER = "mc-server-state=draining";
  private static final Component DRAINING_STATUS = Component.text(DRAINING_STATUS_MARKER);
  private static final Component DRAINING_KICK_MESSAGE =
      Component.text("Server is saving and restarting. Please wait.");

  private Duration gracePeriod;
  private Long emptySinceMillis;
  private boolean shutdownRequested;
  private volatile boolean draining;

  @Override
  public void onEnable() {
    Duration gracePeriod = readDurationSeconds("SHUTDOWN_GRACE_SECONDS", 900);
    Duration pollInterval = readDurationSeconds("POLL_SECONDS", 30);

    this.gracePeriod = gracePeriod;

    Bukkit.getPluginManager().registerEvents(this, this);

    long pollTicks = Math.max(1L, pollInterval.toSeconds() * 20L);
    Bukkit.getScheduler().runTaskTimer(this, this::pollIdleShutdown, pollTicks, pollTicks);

    getLogger()
        .info(
            "Idle shutdown enabled: grace="
                + gracePeriod.toSeconds()
                + "s poll="
                + pollInterval.toSeconds()
                + "s");
  }

  @Override
  public void onDisable() {
    saveWorlds();
  }

  @EventHandler
  public void onServerListPing(ServerListPingEvent event) {
    if (!draining) {
      return;
    }
    event.motd(DRAINING_STATUS);
    event.setMaxPlayers(0);
  }

  @EventHandler
  public void onAsyncPlayerPreLogin(AsyncPlayerPreLoginEvent event) {
    if (!draining) {
      return;
    }
    event.disallow(AsyncPlayerPreLoginEvent.Result.KICK_OTHER, DRAINING_KICK_MESSAGE);
  }

  private void pollIdleShutdown() {
    if (shutdownRequested) {
      return;
    }

    if (!hasBeenEmptyForGracePeriod()) {
      return;
    }

    shutdownRequested = true;
    draining = true;
    getLogger()
        .info("Server has been empty for the shutdown grace period; saving worlds and stopping.");

    saveWorlds();

    Bukkit.shutdown();
  }

  private boolean hasBeenEmptyForGracePeriod() {
    if (!Bukkit.getOnlinePlayers().isEmpty()) {
      emptySinceMillis = null;
      return false;
    }

    long nowMillis = System.currentTimeMillis();
    if (emptySinceMillis == null) {
      emptySinceMillis = nowMillis;
    }

    return nowMillis - emptySinceMillis >= gracePeriod.toMillis();
  }

  private void saveWorlds() {
    for (World world : Bukkit.getWorlds()) {
      world.save();
    }
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
      getLogger()
          .warning("Invalid " + name + "=" + value + "; using " + defaultSeconds + " seconds.");
      return Duration.ofSeconds(defaultSeconds);
    }
  }
}
