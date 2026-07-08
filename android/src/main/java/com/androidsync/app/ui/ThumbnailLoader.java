// android/src/main/java/com/androidsync/app/ui/ThumbnailLoader.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.content.ContentResolver;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.util.LruCache;
import android.util.Size;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import com.androidsync.app.core.ThumbnailPolicy;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;

/**
 * 缩略图/预览加载管线，B17 自 MainActivity 原样搬移（行为零变化）。
 * 原来对 Activity 的 {@code destroyed} 生命周期标志改为本类自有的 {@code shutdown}，
 * 由 {@link #shutdown()} 置位；{@code renderGeneration} 随管线迁入，经 {@link #bumpGeneration()} 递增。
 */
public final class ThumbnailLoader {
    private static final String TAG = "AndroidSync";
    private static final long MIN_THUMBNAIL_CACHE_BYTES = 4L * 1024L * 1024L;
    private static final int FAILED_THUMBNAIL_CACHE_ENTRIES = 256;
    private static final int FAILED_PREVIEW_CACHE_ENTRIES = 64;

    private final Activity activity;
    private final ContentResolver resolver;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService thumbnailExecutor = Executors.newFixedThreadPool(2);
    private final LruCache<String, Bitmap> thumbnailCache = new LruCache<String, Bitmap>(thumbnailCacheBytes()) {
        @Override
        protected int sizeOf(String key, Bitmap bitmap) {
            return bitmap.getAllocationByteCount();
        }
    };
    private final LruCache<String, Boolean> failedThumbnailCache =
            new LruCache<>(FAILED_THUMBNAIL_CACHE_ENTRIES);
    private final LruCache<String, Boolean> failedPreviewCache =
            new LruCache<>(FAILED_PREVIEW_CACHE_ENTRIES);
    private final Object thumbnailRequestsLock = new Object();
    private final Map<String, List<ThumbnailTarget>> thumbnailRequests = new HashMap<>();
    private final Object previewRequestsLock = new Object();
    private final Map<String, PreviewTarget> previewInFlight = new HashMap<>();

    private int renderGeneration;
    private volatile boolean shutdown;

    public ThumbnailLoader(Activity activity, ContentResolver resolver) {
        this.activity = activity;
        this.resolver = resolver;
    }

    public void bumpGeneration() {
        renderGeneration++;
    }

    public void shutdown() {
        shutdown = true;
        synchronized (thumbnailRequestsLock) {
            for (List<ThumbnailTarget> targets : thumbnailRequests.values()) {
                targets.clear();
            }
            thumbnailRequests.clear();
        }
        synchronized (previewRequestsLock) {
            previewInFlight.clear();
        }
        thumbnailExecutor.shutdownNow();
    }

    public void loadThumbnailInto(
        final ImageView image,
        final TextView placeholder,
        final String mediaUri,
        final int requestPixels
    ) {
        if (shutdown) {
            return;
        }
        final String cacheKey = thumbnailCacheKey(mediaUri, requestPixels);
        Bitmap cached = thumbnailCache.get(cacheKey);
        if (cached != null) {
            image.setImageBitmap(cached);
            placeholder.setVisibility(View.GONE);
            return;
        }
        if (failedThumbnailCache.get(cacheKey) != null) {
            return;
        }

        final ThumbnailTarget target = new ThumbnailTarget(image, placeholder, renderGeneration);
        boolean shouldSubmit = false;
        synchronized (thumbnailRequestsLock) {
            if (shutdown) {
                return;
            }
            cached = thumbnailCache.get(cacheKey);
            if (cached == null && failedThumbnailCache.get(cacheKey) == null) {
                List<ThumbnailTarget> targets = thumbnailRequests.get(cacheKey);
                if (targets == null) {
                    targets = new ArrayList<>();
                    thumbnailRequests.put(cacheKey, targets);
                    shouldSubmit = true;
                }
                pruneThumbnailTargets(targets, image);
                targets.add(target);
            }
        }

        if (cached != null) {
            image.setImageBitmap(cached);
            placeholder.setVisibility(View.GONE);
            return;
        }
        if (!shouldSubmit) {
            return;
        }

        try {
            thumbnailExecutor.execute(new Runnable() {
                @Override
                public void run() {
                    Bitmap loadedBitmap = null;
                    try {
                        loadedBitmap = loadThumbnailBitmap(mediaUri, requestPixels);
                        if (loadedBitmap == null) {
                            failedThumbnailCache.put(cacheKey, Boolean.TRUE);
                        } else {
                            thumbnailCache.put(cacheKey, loadedBitmap);
                        }
                    } finally {
                        final List<ThumbnailTarget> targets;
                        synchronized (thumbnailRequestsLock) {
                            List<ThumbnailTarget> inFlightTargets = thumbnailRequests.remove(cacheKey);
                            targets = inFlightTargets == null
                                    ? null
                                    : new ArrayList<>(inFlightTargets);
                            if (inFlightTargets != null) {
                                inFlightTargets.clear();
                            }
                        }
                        if (targets != null && !shutdown) {
                            final Bitmap bitmap = loadedBitmap;
                            postTask(new Runnable() {
                                @Override
                                public void run() {
                                    completeThumbnailRequest(mediaUri, bitmap, targets);
                                }
                            });
                        }
                    }
                }
            });
        } catch (RejectedExecutionException error) {
            synchronized (thumbnailRequestsLock) {
                List<ThumbnailTarget> targets = thumbnailRequests.remove(cacheKey);
                if (targets != null) {
                    targets.clear();
                }
            }
        }
    }

    private void pruneThumbnailTargets(List<ThumbnailTarget> targets, ImageView currentImage) {
        for (int index = targets.size() - 1; index >= 0; index--) {
            ThumbnailTarget target = targets.get(index);
            ImageView targetImage = target.image.get();
            if (targetImage == null
                    || targetImage == currentImage
                    || (!targetImage.isAttachedToWindow()
                    && target.renderGeneration != renderGeneration)) {
                targets.remove(index);
            }
        }
    }

    private void completeThumbnailRequest(
        String mediaUri,
        Bitmap bitmap,
        List<ThumbnailTarget> targets
    ) {
        if (shutdown || bitmap == null) {
            return;
        }
        for (ThumbnailTarget target : targets) {
            ImageView image = target.image.get();
            if (image == null || !mediaUri.equals(image.getTag()) || !image.isAttachedToWindow()) {
                continue;
            }
            image.setImageBitmap(bitmap);
            TextView placeholder = target.placeholder.get();
            if (placeholder != null && placeholder.isAttachedToWindow()) {
                placeholder.setVisibility(View.GONE);
            }
        }
    }

    private Bitmap loadThumbnailBitmap(String mediaUri, int requestPixels) {
        if (Build.VERSION.SDK_INT < 29) {
            return null;
        }
        try {
            return resolver.loadThumbnail(Uri.parse(mediaUri), new Size(requestPixels, requestPixels), null);
        } catch (OutOfMemoryError error) {
            Log.w(TAG, "Unable to load thumbnail " + mediaUri, error);
            return null;
        } catch (Exception error) {
            Log.w(TAG, "Unable to load thumbnail " + mediaUri, error);
            return null;
        }
    }

    public void loadPreviewAsync(final ImageView image, final TextView loading, final String mediaUri) {
        if (shutdown) {
            return;
        }
        image.setTag(mediaUri);
        final int availableWidth = Math.max(1, activity.getResources().getDisplayMetrics().widthPixels);
        final int requestPixels = ThumbnailPolicy.previewRequestPixels(availableWidth);
        final String cacheKey = thumbnailCacheKey(mediaUri, requestPixels);
        if (failedPreviewCache.get(cacheKey) != null) {
            loading.setText("无法加载预览");
            return;
        }

        final PreviewTarget target = new PreviewTarget(image, loading);
        boolean shouldSubmit = false;
        boolean failed = false;
        synchronized (previewRequestsLock) {
            if (shutdown) {
                return;
            }
            if (failedPreviewCache.get(cacheKey) != null) {
                failed = true;
            } else if (previewInFlight.containsKey(cacheKey)) {
                previewInFlight.put(cacheKey, target);
            } else {
                previewInFlight.put(cacheKey, target);
                shouldSubmit = true;
            }
        }
        if (failed) {
            loading.setText("无法加载预览");
            return;
        }
        if (!shouldSubmit) {
            return;
        }

        try {
            thumbnailExecutor.execute(new Runnable() {
                @Override
                public void run() {
                    Bitmap loadedBitmap = null;
                    try {
                        loadedBitmap = loadPreviewBitmap(mediaUri, requestPixels);
                        if (loadedBitmap == null) {
                            failedPreviewCache.put(cacheKey, Boolean.TRUE);
                        }
                    } finally {
                        final PreviewTarget completedTarget;
                        synchronized (previewRequestsLock) {
                            completedTarget = previewInFlight.remove(cacheKey);
                        }
                        if (completedTarget != null && !shutdown) {
                            final Bitmap bitmap = loadedBitmap;
                            postTask(new Runnable() {
                                @Override
                                public void run() {
                                    completePreviewRequest(mediaUri, bitmap, completedTarget);
                                }
                            });
                        }
                    }
                }
            });
        } catch (RejectedExecutionException error) {
            synchronized (previewRequestsLock) {
                previewInFlight.remove(cacheKey);
            }
        }
    }

    private void completePreviewRequest(String mediaUri, Bitmap bitmap, PreviewTarget target) {
        if (shutdown) {
            return;
        }
        ImageView image = target.image.get();
        TextView loading = target.loading.get();
        if (image == null || loading == null
                || !mediaUri.equals(image.getTag())
                || !image.isAttachedToWindow()
                || !loading.isAttachedToWindow()) {
            return;
        }
        if (bitmap == null) {
            loading.setText("无法加载预览");
            return;
        }
        image.setImageBitmap(bitmap);
        loading.setVisibility(View.GONE);
    }

    private Bitmap loadPreviewBitmap(String mediaUri, int requestPixels) {
        if (Build.VERSION.SDK_INT < 29) {
            return null;
        }
        try {
            return resolver.loadThumbnail(Uri.parse(mediaUri), new Size(requestPixels, requestPixels), null);
        } catch (OutOfMemoryError error) {
            Log.w(TAG, "Unable to load preview " + mediaUri, error);
            return null;
        } catch (Exception error) {
            Log.w(TAG, "Unable to load preview " + mediaUri, error);
            return null;
        }
    }

    private void postTask(final Runnable task) {
        if (shutdown) {
            return;
        }
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                if (!shutdown) {
                    task.run();
                }
            }
        });
    }

    private static int thumbnailCacheBytes() {
        long requestedBytes = Math.max(MIN_THUMBNAIL_CACHE_BYTES, Runtime.getRuntime().maxMemory() / 16L);
        return (int) Math.min((long) Integer.MAX_VALUE, requestedBytes);
    }

    private static String thumbnailCacheKey(String mediaUri, int requestPixels) {
        return mediaUri + "#" + requestPixels + "x" + requestPixels;
    }

    private static final class ThumbnailTarget {
        private final WeakReference<ImageView> image;
        private final WeakReference<TextView> placeholder;
        private final int renderGeneration;

        private ThumbnailTarget(ImageView image, TextView placeholder, int renderGeneration) {
            this.image = new WeakReference<>(image);
            this.placeholder = new WeakReference<>(placeholder);
            this.renderGeneration = renderGeneration;
        }
    }

    private static final class PreviewTarget {
        private final WeakReference<ImageView> image;
        private final WeakReference<TextView> loading;

        private PreviewTarget(ImageView image, TextView loading) {
            this.image = new WeakReference<>(image);
            this.loading = new WeakReference<>(loading);
        }
    }
}
