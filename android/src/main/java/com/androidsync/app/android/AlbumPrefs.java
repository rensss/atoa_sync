// android/src/main/java/com/androidsync/app/android/AlbumPrefs.java
package com.androidsync.app.android;

import android.content.SharedPreferences;

import java.util.HashSet;
import java.util.Set;

public final class AlbumPrefs {
    private static final String KEY = "album_whitelist";

    public static Set<String> load(SharedPreferences prefs) {
        Set<String> stored = prefs.getStringSet(KEY, null);
        return stored == null ? null : new HashSet<>(stored);
    }

    public static void save(SharedPreferences prefs, Set<String> bucketIds) {
        prefs.edit().putStringSet(KEY, new HashSet<>(bucketIds)).apply();
    }

    public static boolean isConfigured(SharedPreferences prefs) {
        return prefs.getStringSet(KEY, null) != null;
    }

    private AlbumPrefs() {
    }
}
