package com.androidsync.app.core;

import java.util.concurrent.atomic.AtomicLong;

public final class SyncRunGate {
    private final AtomicLong nextGeneration = new AtomicLong();
    private final AtomicLong activeGeneration = new AtomicLong();

    public long start() {
        long generation = nextGeneration.incrementAndGet();
        activeGeneration.set(generation);
        return generation;
    }

    public void cancel() {
        activeGeneration.set(0L);
    }

    public boolean finish(long generation) {
        return activeGeneration.compareAndSet(generation, 0L);
    }

    public boolean isActive(long generation) {
        return generation != 0L && activeGeneration.get() == generation;
    }

    public boolean isActive() {
        return activeGeneration.get() != 0L;
    }
}
