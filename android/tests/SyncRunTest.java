import com.androidsync.app.core.SyncRun;
import com.androidsync.app.core.SyncRunStatus;

public final class SyncRunTest {
    public static void main(String[] args) {
        runKeepsFrozenTargetAndLifecycleState();
    }

    private static void runKeepsFrozenTargetAndLifecycleState() {
        SyncRun run = SyncRun.start("run-1", "http://receiver/uploads/", 100L);

        assertEquals("run-1", run.id(), "run should keep its id");
        assertEquals("http://receiver/uploads/", run.targetUrl(), "run should freeze target URL");
        assertEquals(SyncRunStatus.RUNNING, run.status(), "new run should be running");
        assertEquals(100L, run.createdAtMillis(), "run should keep creation time");

        SyncRun stopped = run.withStatus(SyncRunStatus.STOPPED, 200L);
        assertEquals(SyncRunStatus.STOPPED, stopped.status(), "run should transition to stopped");
        assertEquals("http://receiver/uploads/", stopped.targetUrl(), "status transition must not change target URL");
        assertEquals(200L, stopped.updatedAtMillis(), "status transition should update timestamp");
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }
}
