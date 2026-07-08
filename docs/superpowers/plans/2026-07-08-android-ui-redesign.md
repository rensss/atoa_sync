# Android UI 重设计与文件选择实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 `docs/superpowers/specs/2026-07-08-android-ui-redesign-design.md` 把 Android 端重做为深色媒体库首页（macOS 镜像）：Theme token、MainActivity 拆巨石、相册白名单 + 确认态临时排除两层文件选择、传输卡片行、设备名 header。

**Architecture:** 渐进重构。MainActivity 保留权限、生命周期、SyncQueue 驱动与页面组装；UI 拆入新 `android/ui/` 包；纯逻辑入 `core/AlbumFilter`（JVM 可测）。旧 home/queue/detail 页在新媒体库页落地的同一批次删除。

**Tech Stack:** 纯 Android framework（Activity + 程序化 LinearLayout，无 XML、无第三方依赖），JVM javac/java 测试 harness（只编译 `core` 包）。

## Global Constraints

- 不新增第三方依赖、不引入 Compose/XML 布局；沿用程序化 View 构建。
- `minSdkVersion 26`；MediaStore bucket 列（`BUCKET_ID`/`BUCKET_DISPLAY_NAME`）API 29 起在 MediaColumns 公开，26–28 用字符串常量 `"bucket_id"`/`"bucket_display_name"`（两版本列名相同）。
- 每个任务收尾：`./android/run_tests.sh` 通过 + `./android/build.sh` 产出 APK。
- UI 层无自动化测试（harness 只编译 `core`）；涉及 UI 的任务在报告里如实声明"真机 QA 未执行"，不得表述为已验证。
- 色板 token 与 macOS `Theme.swift` 数值一致：bg #1E1E23、bgRaised #2B2B31、bgSidebar #1C1C21、stroke #38383F、textPrimary #EEEEF0、textSecondary #9A9AA3、accent #E8A33D、渐变 #4F7CF0→#6A5CD8、statusRunning #4CD964、statusFailed #FF5F57；间距 dp 4/8/12/16；圆角 dp 6/10。
- 用户可见文案沿用现状（硬编码简体中文字符串，如 `"等待扫描"`）；不引入新的本地化机制。
- 任务与 spec 批次对应：Task 1=B17、Task 2–3=B18、Task 4–5=B19、Task 6–7=B20、Task 8=B21。每批次最后一个任务提交后，控制器在 `PROJECT_MEMORY/batches/` 记录批次（编号顺延）并更新 `00_PROJECT_STATUS.md`/`HANDOFF.md`（实施者不改 PROJECT_MEMORY）。
- 提交落在 `codex/android-ui-redesign` 分支（自 `main` 最新拉出）。
- 提交信息末尾加 trailer：`Claude-Session: https://claude.ai/code/session_01R8iA7u3mry5aWSJLqCtNe2`。

---

### Task 1: Theme token 与 MainActivity 拆壳（B17，纯搬移不改逻辑）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/Theme.java`
- Create: `android/src/main/java/com/androidsync/app/ui/Widgets.java`
- Create: `android/src/main/java/com/androidsync/app/ui/ThumbnailLoader.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`

**Interfaces:**
- Consumes: 现有 MainActivity 私有 helper（下表）。
- Produces:
  - `Theme`：静态常量 `BG/BG_RAISED/BG_SIDEBAR/STROKE/TEXT_PRIMARY/TEXT_SECONDARY/ACCENT/GRADIENT_START/GRADIENT_END/STATUS_RUNNING/STATUS_FAILED`（`String` 十六进制色值）与 `SPACE_XS=4/SPACE_S=8/SPACE_M=12/SPACE_L=16/RADIUS_S=6/RADIUS_L=10`（`int` dp 值）。
  - `Widgets`（构造 `Widgets(Activity activity)`）：`int dp(int)`、`int color(String)`、`GradientDrawable rounded(String fill, String stroke, int strokeDp, int radiusDp)`、`LinearLayout pageLayout()`、`LinearLayout card()`、`TextView title(String,int)`、`TextView sectionHeader(String)`、`TextView label(String,int,String)`、`TextView icon(String)`、`Button actionButton(String, View.OnClickListener)`、`Button smallButton(String)`、`TextView textButton(String,String,String)`、`LinearLayout.LayoutParams weightParams()`、`int statusBarHeight()`——签名与原 MainActivity 同名方法一致，实现原样搬移。
  - `ThumbnailLoader`（构造 `ThumbnailLoader(Activity activity, ContentResolver resolver)`）：搬移缩略图/预览管线——`loadThumbnailInto(ImageView, TextView, String mediaUri, int requestPixels)`（原 `thumbnail(SyncTask)` 中的加载片段拆出）、`loadPreviewAsync(ImageView, TextView, String)`、内部持有 `thumbnailCache/failedThumbnailCache/failedPreviewCache/thumbnailExecutor/thumbnailRequests/previewInFlight` 及 `ThumbnailTarget/PreviewTarget` 类、`loadThumbnailBitmap/loadPreviewBitmap/completePreviewRequest/pruneThumbnailTargets/thumbnailCacheBytes/thumbnailCacheKey` 方法，另暴露 `void shutdown()`（关 executor）与 `void bumpGeneration()`（对应 `renderGeneration` 递增）。

- [ ] **Step 1: 写 Theme.java**

```java
// android/src/main/java/com/androidsync/app/ui/Theme.java
package com.androidsync.app.ui;

/**
 * 深色工作台主题 token，数值与 macOS 端 Theme.swift 一致
 * （docs/superpowers/specs/2026-07-08-android-ui-redesign-design.md）。
 * 本批次只定义，不接线；各页在 B18–B20 重画时改用这里的值。
 */
public final class Theme {
    public static final String BG = "#1E1E23";
    public static final String BG_RAISED = "#2B2B31";
    public static final String BG_SIDEBAR = "#1C1C21";
    public static final String STROKE = "#38383F";
    public static final String TEXT_PRIMARY = "#EEEEF0";
    public static final String TEXT_SECONDARY = "#9A9AA3";
    public static final String ACCENT = "#E8A33D";
    public static final String GRADIENT_START = "#4F7CF0";
    public static final String GRADIENT_END = "#6A5CD8";
    public static final String STATUS_RUNNING = "#4CD964";
    public static final String STATUS_FAILED = "#FF5F57";

    public static final int SPACE_XS = 4;
    public static final int SPACE_S = 8;
    public static final int SPACE_M = 12;
    public static final int SPACE_L = 16;
    public static final int RADIUS_S = 6;
    public static final int RADIUS_L = 10;

    private Theme() {
    }
}
```

- [ ] **Step 2: 建 Widgets.java（纯搬移）**

新建 `Widgets`，构造函数存 `Activity`。把 MainActivity 下列方法**原样剪切**过来改为 `public`（方法体逐字保留，仅把对 Activity 的隐式引用改为字段 `activity`）：

| 原方法（MainActivity 行号，2026-07-08 基线） | 去向 |
|---|---|
| `pageLayout()` :1643 | `Widgets.pageLayout()` |
| `card()` :1650 | `Widgets.card()` |
| `title(String,int)` :1661 | `Widgets.title(...)` |
| `sectionHeader(String)` :1667 | `Widgets.sectionHeader(...)` |
| `label(String,int,String)` :1674 | `Widgets.label(...)` |
| `icon(String)` :1683 | `Widgets.icon(...)` |
| `actionButton(String,OnClickListener)` :1691 | `Widgets.actionButton(...)` |
| `smallButton(String)` :1699 | `Widgets.smallButton(...)` |
| `textButton(String,String,String)` :1711 | `Widgets.textButton(...)` |
| `weightParams()` :1745 | `Widgets.weightParams()` |
| `color(String)` :1853 | `Widgets.color(...)` |
| `rounded(String,String,int,int)` :1857 | `Widgets.rounded(...)` |
| `dp(int)` :1867 | `Widgets.dp(...)` |
| `statusBarHeight()` :1871 | `Widgets.statusBarHeight()` |

MainActivity 增加字段 `private Widgets widgets;`（`onCreate` 里 `widgets = new Widgets(this);` 在 `render()` 之前），原调用点全部改为 `widgets.xxx(...)`。不留同名转发方法。

- [ ] **Step 3: 建 ThumbnailLoader.java（纯搬移）**

搬移缩略图/预览管线（Interfaces 列出的字段、内部类与方法，MainActivity 行号 88–103、1029–1135、1333–1519）。要点：
- `ThumbnailTarget/PreviewTarget` 属于管线随迁；`QueueRowViews` 留在 MainActivity。
- 原 `thumbnail(SyncTask)` :1333 是"建 View + 触发加载"混合体：View 构建部分留 MainActivity（本批次不动），触发加载的片段改调 `thumbnailLoader.loadThumbnailInto(image, placeholder, task.mediaUri(), requestPixels)`。
- `renderGeneration` 比对逻辑随管线走：MainActivity 的 `render()` 现有递增处改调 `thumbnailLoader.bumpGeneration()`。
- `onDestroy()` 中缩略图 executor 关闭行改为 `thumbnailLoader.shutdown()`。
- MainActivity 增加字段 `private ThumbnailLoader thumbnailLoader;`，`onCreate` 里 `thumbnailLoader = new ThumbnailLoader(this, getContentResolver());`。

- [ ] **Step 4: 编译与测试**

Run: `./android/run_tests.sh && ./android/build.sh`
Expected: 测试通过；APK 生成。行为零变化（纯搬移）——`git diff --stat` 里 MainActivity 应净减约 500 行。

- [ ] **Step 5: 提交**

```bash
git add android/src/main/java/com/androidsync/app/ui/ android/src/main/java/com/androidsync/app/MainActivity.java
git commit -m "refactor: B17 Theme token 与 MainActivity 拆壳"
```

---

### Task 2: 扫描器 bucket 过滤与白名单持久化（B18 前半）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/android/AlbumPrefs.java`
- Modify: `android/src/main/java/com/androidsync/app/android/MediaStoreScanner.java`
- Modify: `android/src/main/java/com/androidsync/app/core/MediaItem.java`（加 `bucketId`/`bucketName` 字段）
- Test: `android/tests/SyncQueueTest.java`（仅当编译要求时同步构造点）

**Interfaces:**
- Consumes: 现有 `MediaStoreScanner.scan(...)`、`MediaItem` 构造函数。
- Produces:
  - `MediaItem` 新增末尾构造参数 `String bucketId, String bucketName`（旧构造重载保留，委托新构造传 `null,null`）；新增访问器 `String bucketId()`、`String bucketName()`。
  - `MediaStoreScanner.scanAll(java.util.Set<String> bucketIds)`：null 不过滤（内部相册枚举用）；非 null 时 selection `bucket_id IN (?,...)`。原 `scanAll()` 保留并委托 `scanAll(null)`。
  - `MediaStoreScanner.listAlbums()`：返回 `List<Album>`；静态类 `Album { public final String bucketId; public final String name; public final int count; }`，全库聚合去重、按 count 降序。
  - `AlbumPrefs`：`static Set<String> load(SharedPreferences)`（key `"album_whitelist"`，未配置返回 null）、`static void save(SharedPreferences, Set<String>)`、`static boolean isConfigured(SharedPreferences)`。

- [ ] **Step 1: MediaItem 加 bucket 字段**

现有主构造（9 参）尾部追加 `String bucketId, String bucketName` 存为 final 字段，加访问器；保留旧 9 参构造委托新构造传 `null, null`。`SyncQueueTest` 用旧重载则无需改。

- [ ] **Step 2: 扫描器过滤与相册枚举**

```java
// MediaStoreScanner 内新增（原方法保留，projection 追加两列）
private static final String BUCKET_ID = "bucket_id";
private static final String BUCKET_NAME = "bucket_display_name";

public List<MediaItem> scanAll(java.util.Set<String> bucketIds) {
    List<MediaItem> items = new ArrayList<>();
    scanImages(items, bucketIds);
    scanVideos(items, bucketIds);
    Collections.sort(items, new Comparator<MediaItem>() {
        @Override
        public int compare(MediaItem left, MediaItem right) {
            return Long.compare(right.dateModifiedMillis(), left.dateModifiedMillis());
        }
    });
    return items;
}

public List<Album> listAlbums() {
    java.util.LinkedHashMap<String, int[]> counts = new java.util.LinkedHashMap<>();
    java.util.LinkedHashMap<String, String> names = new java.util.LinkedHashMap<>();
    countBuckets(imagesCollection(), counts, names);
    countBuckets(videosCollection(), counts, names);
    List<Album> albums = new ArrayList<>();
    for (java.util.Map.Entry<String, int[]> entry : counts.entrySet()) {
        albums.add(new Album(entry.getKey(), names.get(entry.getKey()), entry.getValue()[0]));
    }
    Collections.sort(albums, new Comparator<Album>() {
        @Override
        public int compare(Album left, Album right) {
            return Integer.compare(right.count, left.count);
        }
    });
    return albums;
}

private void countBuckets(Uri collection, java.util.Map<String, int[]> counts, java.util.Map<String, String> names) {
    String[] projection = new String[] { BUCKET_ID, BUCKET_NAME };
    Cursor cursor = resolver.query(collection, projection, null, null, null);
    if (cursor == null) {
        return;
    }
    try {
        int idColumn = cursor.getColumnIndexOrThrow(BUCKET_ID);
        int nameColumn = cursor.getColumnIndexOrThrow(BUCKET_NAME);
        while (cursor.moveToNext()) {
            String id = cursor.getString(idColumn);
            if (id == null) {
                continue;
            }
            String name = cursor.getString(nameColumn);
            int[] count = counts.get(id);
            if (count == null) {
                counts.put(id, new int[] { 1 });
                names.put(id, name == null ? id : name);
            } else {
                count[0]++;
            }
        }
    } finally {
        cursor.close();
    }
}

public static final class Album {
    public final String bucketId;
    public final String name;
    public final int count;

    public Album(String bucketId, String name, int count) {
        this.bucketId = bucketId;
        this.name = name;
        this.count = count;
    }
}
```

`imagesCollection()/videosCollection()`：把现 `scanImages/scanVideos` 里的 collection 选择逻辑提为私有方法复用。`scan(...)` 加参数 `Set<String> bucketIds`：非 null 时 `selection = "bucket_id IN (" + join(",", nCopies(size, "?")) + ")"`、`selectionArgs = bucketIds.toArray(new String[0])`；projection 追加 `BUCKET_ID/BUCKET_NAME` 并读入 `MediaItem` 新字段。

- [ ] **Step 3: AlbumPrefs**

```java
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
```

- [ ] **Step 4: 编译测试提交**

Run: `./android/run_tests.sh && ./android/build.sh` → 通过。

```bash
git add android/src/main/java/com/androidsync/app/android/ android/src/main/java/com/androidsync/app/core/MediaItem.java android/tests/
git commit -m "feat: B18 扫描器 bucket 过滤与相册白名单持久化"
```

---

### Task 3: AlbumPickerView、新设置页与首启引导（B18 后半）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/AlbumPickerView.java`
- Create: `android/src/main/java/com/androidsync/app/ui/SettingsPageView.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`

**Interfaces:**
- Consumes: Task 1 `Widgets/Theme`、Task 2 `MediaStoreScanner.listAlbums()/AlbumPrefs`。
- Produces:
  - `AlbumPickerView`：构造 `(Activity, Widgets)`；`View build(List<MediaStoreScanner.Album> albums, Set<String> selected, Runnable onChanged)`。
  - `SettingsPageView`：构造 `(Activity, Widgets)`；`View build(SettingsHost host)`；接口 `SettingsHost { String targetUrl(); void editTarget(); void openAlbumPicker(); String appVersionText(); int whitelistCount(); }`。
  - MainActivity：`screen` 增加 `"albumPicker"`；首启未配置白名单强制引导（预勾 name 为 `"Camera"` 的 bucket，至少选一个才能完成）；`scanMedia()` 改用 `scanner.scanAll(AlbumPrefs.load(prefs()))`，未配置时置 `scanMessage = "请先选择同步相册"` 并 return。

- [ ] **Step 1: AlbumPickerView 完整实现**

```java
// android/src/main/java/com/androidsync/app/ui/AlbumPickerView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.View;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.android.MediaStoreScanner;

import java.util.List;
import java.util.Set;

public final class AlbumPickerView {
    private final Activity activity;
    private final Widgets widgets;

    public AlbumPickerView(Activity activity, Widgets widgets) {
        this.activity = activity;
        this.widgets = widgets;
    }

    public View build(List<MediaStoreScanner.Album> albums, final Set<String> selected, final Runnable onChanged) {
        LinearLayout list = new LinearLayout(activity);
        list.setOrientation(LinearLayout.VERTICAL);
        for (final MediaStoreScanner.Album album : albums) {
            LinearLayout row = widgets.card();
            row.setOrientation(LinearLayout.HORIZONTAL);
            final CheckBox box = new CheckBox(activity);
            box.setChecked(selected.contains(album.bucketId));
            TextView name = widgets.label(album.name + "  ·  " + album.count + " 项", 15, Theme.TEXT_PRIMARY);
            row.addView(box);
            row.addView(name, widgets.weightParams());
            View.OnClickListener toggle = new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (selected.contains(album.bucketId)) {
                        selected.remove(album.bucketId);
                    } else {
                        selected.add(album.bucketId);
                    }
                    box.setChecked(selected.contains(album.bucketId));
                    onChanged.run();
                }
            };
            row.setOnClickListener(toggle);
            box.setOnClickListener(toggle);
            list.addView(row);
        }
        ScrollView scroll = new ScrollView(activity);
        scroll.setBackgroundColor(widgets.color(Theme.BG));
        scroll.addView(list);
        return scroll;
    }
}
```

- [ ] **Step 2: SettingsPageView 完整实现**

```java
// android/src/main/java/com/androidsync/app/ui/SettingsPageView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;

public final class SettingsPageView {
    public interface SettingsHost {
        String targetUrl();
        void editTarget();
        void openAlbumPicker();
        String appVersionText();
        int whitelistCount();
    }

    private final Activity activity;
    private final Widgets widgets;

    public SettingsPageView(Activity activity, Widgets widgets) {
        this.activity = activity;
        this.widgets = widgets;
    }

    public View build(final SettingsHost host) {
        LinearLayout page = widgets.pageLayout();
        page.setBackgroundColor(widgets.color(Theme.BG));

        page.addView(widgets.sectionHeader("同步相册"));
        LinearLayout albums = widgets.card();
        albums.setOrientation(LinearLayout.HORIZONTAL);
        albums.addView(widgets.label("已选 " + host.whitelistCount() + " 个相册", 14, Theme.TEXT_PRIMARY), widgets.weightParams());
        Button manage = widgets.smallButton("管理");
        manage.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.openAlbumPicker();
            }
        });
        albums.addView(manage);
        page.addView(albums);

        page.addView(widgets.sectionHeader("接收端"));
        LinearLayout target = widgets.card();
        target.setOrientation(LinearLayout.HORIZONTAL);
        target.addView(widgets.label(host.targetUrl(), 13, Theme.TEXT_SECONDARY), widgets.weightParams());
        Button edit = widgets.smallButton("修改");
        edit.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.editTarget();
            }
        });
        target.addView(edit);
        page.addView(target);

        page.addView(widgets.sectionHeader("关于"));
        LinearLayout about = widgets.card();
        about.addView(widgets.label(host.appVersionText(), 13, Theme.TEXT_SECONDARY));
        page.addView(about);
        return page;
    }
}
```

- [ ] **Step 3: MainActivity 接线**

- 字段：`private final java.util.Set<String> albumSelection = new java.util.HashSet<>();`、`private List<MediaStoreScanner.Album> albums = java.util.Collections.emptyList();`
- `render()` 加 `"albumPicker"` 分支：`AlbumPickerView.build(albums, albumSelection, onChanged)` + 底部 `actionButton("完成", ...)`（`albumSelection.isEmpty()` 时 `setEnabled(false)`；完成时 `AlbumPrefs.save(prefs(), albumSelection)`、`screen` 回上一页、`scanMedia()`）。`albums` 在进入该分支前于 executor 上 `scanner.listAlbums()` 加载后 post 回主线程 render。
- 首启：权限通过后 `!AlbumPrefs.isConfigured(prefs())` → `screen = "albumPicker"`，`albumSelection` 预勾 `listAlbums()` 中 `name.equals("Camera")` 的 bucketId。
- `scanMedia()`（:196）改造如上。
- 旧 `settingsView()`（:669）体替换为 `new SettingsPageView(this, widgets).build(host)`，host 匿名实现桥接 `targetUrl`/`editTarget()`/`appVersionText()`/`AlbumPrefs`；`openAlbumPicker()` 置 `screen = "albumPicker"` 并 render。

- [ ] **Step 4: 编译测试提交**

Run: `./android/run_tests.sh && ./android/build.sh` → 通过。报告声明真机 QA 未执行。

```bash
git add android/src/main/java/com/androidsync/app/
git commit -m "feat: B18 相册白名单选择页与设置页"
```

---

### Task 4: core/AlbumFilter 与 JVM 测试（B19 前半）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/core/AlbumFilter.java`
- Create: `android/tests/AlbumFilterTest.java`
- Modify: `android/run_tests.sh`

**Interfaces:**
- Consumes: `core/MediaItem`（含 Task 2 的 `bucketId()`、11 参构造）。
- Produces:
  - `AlbumFilter.Selection { public final List<MediaItem> pending; public final long totalBytes; }`
  - `static Selection pending(List<MediaItem> scanned, Set<String> syncedStableIds, Set<String> excludedStableIds)`
  - `static boolean inWhitelist(MediaItem item, Set<String> bucketIds)`——null 白名单 = false（未配置不放行）。

- [ ] **Step 1: 写失败测试**

```java
// android/tests/AlbumFilterTest.java
import com.androidsync.app.core.AlbumFilter;
import com.androidsync.app.core.MediaItem;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class AlbumFilterTest {
    public static void main(String[] args) {
        testPendingFiltersSyncedAndExcluded();
        testWhitelistNullMeansNotConfigured();
        System.out.println("AlbumFilterTest passed");
    }

    private static MediaItem item(String id, long size, String bucket) {
        return new MediaItem(id, "content://" + id, id + ".jpg", size, 0L, 0L, 0L, false, "image/jpeg", bucket, bucket);
    }

    private static void testPendingFiltersSyncedAndExcluded() {
        List<MediaItem> scanned = Arrays.asList(
                item("a", 10, "cam"), item("b", 20, "cam"), item("c", 30, "cam"));
        Set<String> synced = new HashSet<>(Collections.singletonList("a"));
        Set<String> excluded = new HashSet<>(Collections.singletonList("c"));
        AlbumFilter.Selection sel = AlbumFilter.pending(scanned, synced, excluded);
        assertEquals(1, sel.pending.size());
        assertEquals("b", sel.pending.get(0).stableId());
        assertEquals(20L, sel.totalBytes);
    }

    private static void testWhitelistNullMeansNotConfigured() {
        assertEquals(false, AlbumFilter.inWhitelist(item("a", 1, "cam"), null));
        Set<String> allow = new HashSet<>(Collections.singletonList("cam"));
        assertEquals(true, AlbumFilter.inWhitelist(item("a", 1, "cam"), allow));
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }

    private static void assertEquals(long expected, long actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
```

（`MediaItem` 11 参构造以 Task 2 实际签名为准；`stableId()` 为现有访问器。）

`run_tests.sh`：`printf` 行后追加

```bash
printf '%s\n' "$ROOT/tests/AlbumFilterTest.java" >> "$ROOT/build/test-sources.list"
```

末尾追加 `java -cp "$BUILD" AlbumFilterTest`。

- [ ] **Step 2: 跑测试确认失败**

Run: `./android/run_tests.sh`
Expected: 编译失败 `cannot find symbol: class AlbumFilter`

- [ ] **Step 3: 实现**

```java
// android/src/main/java/com/androidsync/app/core/AlbumFilter.java
package com.androidsync.app.core;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public final class AlbumFilter {
    public static final class Selection {
        public final List<MediaItem> pending;
        public final long totalBytes;

        public Selection(List<MediaItem> pending, long totalBytes) {
            this.pending = pending;
            this.totalBytes = totalBytes;
        }
    }

    public static Selection pending(List<MediaItem> scanned, Set<String> syncedStableIds, Set<String> excludedStableIds) {
        List<MediaItem> pending = new ArrayList<>();
        long totalBytes = 0L;
        for (MediaItem item : scanned) {
            if (syncedStableIds.contains(item.stableId())) {
                continue;
            }
            if (excludedStableIds.contains(item.stableId())) {
                continue;
            }
            pending.add(item);
            totalBytes += item.sizeBytes();
        }
        return new Selection(pending, totalBytes);
    }

    public static boolean inWhitelist(MediaItem item, Set<String> bucketIds) {
        return bucketIds != null && bucketIds.contains(item.bucketId());
    }

    private AlbumFilter() {
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + 提交**

Run: `./android/run_tests.sh && ./android/build.sh` → 输出含 `AlbumFilterTest passed`。

```bash
git add android/src/main/java/com/androidsync/app/core/AlbumFilter.java android/tests/AlbumFilterTest.java android/run_tests.sh
git commit -m "feat: B19 AlbumFilter 待传集合纯逻辑与 JVM 测试"
```

---

### Task 5: 确认态 ConfirmSelectionView（B19 后半）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/ConfirmSelectionView.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`（`startSync()` :248 前插入确认态）、`android/src/main/java/com/androidsync/app/ui/Widgets.java`（`formatBytes` 移入为 `public static`）

**Interfaces:**
- Consumes: Task 1 `Widgets/Theme/ThumbnailLoader`、Task 4 `AlbumFilter`。
- Produces:
  - `ConfirmSelectionView`：构造 `(Activity, Widgets, ThumbnailLoader)`；`View build(List<MediaItem> pending, Set<String> excluded, ConfirmHost host)`；接口 `ConfirmHost { void onConfirm(); void onCancel(); void onSelectionChanged(int count, long bytes); }`。
  - `Widgets.formatBytes(long)`（原 MainActivity :1812 移入，`public static`，原调用点改引用）。
  - MainActivity：`screen` 增加 `"confirm"`；字段 `private final Set<String> confirmExcluded = new HashSet<>();`；"开始同步"入口改为 `confirmExcluded.clear(); screen = "confirm"; render();`；`onConfirm()` 调 `startSync()`；`startSync()` 入队清单用 `AlbumFilter.pending(scanned, syncedIds, confirmExcluded)` 计算（syncedIds 取现有循环中"已完成任务跳过"判定所用的 stableId 集合）。

- [ ] **Step 1: ConfirmSelectionView 完整实现**

```java
// android/src/main/java/com/androidsync/app/ui/ConfirmSelectionView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.core.MediaItem;

import java.util.List;
import java.util.Set;

public final class ConfirmSelectionView {
    public interface ConfirmHost {
        void onConfirm();
        void onCancel();
        void onSelectionChanged(int count, long bytes);
    }

    private final Activity activity;
    private final Widgets widgets;
    private final ThumbnailLoader thumbnails;

    public ConfirmSelectionView(Activity activity, Widgets widgets, ThumbnailLoader thumbnails) {
        this.activity = activity;
        this.widgets = widgets;
        this.thumbnails = thumbnails;
    }

    public View build(final List<MediaItem> pending, final Set<String> excluded, final ConfirmHost host) {
        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(widgets.color(Theme.BG));

        page.addView(widgets.label("待传 " + pending.size() + " 项 · 点击排除", 13, Theme.TEXT_SECONDARY));

        final Button confirm = widgets.actionButton("", null);

        GridLayout grid = new GridLayout(activity);
        grid.setColumnCount(3);
        int cellSize = (activity.getResources().getDisplayMetrics().widthPixels
                - widgets.dp(Theme.SPACE_L) * 2) / 3 - widgets.dp(2);
        for (final MediaItem item : pending) {
            final FrameLayout cell = new FrameLayout(activity);
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = cellSize;
            params.height = cellSize;
            params.setMargins(widgets.dp(1), widgets.dp(1), widgets.dp(1), widgets.dp(1));
            ImageView image = new ImageView(activity);
            image.setScaleType(ImageView.ScaleType.CENTER_CROP);
            image.setBackgroundColor(widgets.color(Theme.BG_RAISED));
            TextView placeholder = widgets.label("…", 12, Theme.TEXT_SECONDARY);
            cell.addView(image);
            cell.addView(placeholder);
            final TextView mark = widgets.label("✕", 18, Theme.TEXT_PRIMARY);
            mark.setGravity(Gravity.CENTER);
            boolean off = excluded.contains(item.stableId());
            mark.setVisibility(off ? View.VISIBLE : View.GONE);
            cell.setAlpha(off ? 0.35f : 1f);
            cell.addView(mark);
            thumbnails.loadThumbnailInto(image, placeholder, item.uri(), cellSize);
            cell.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (excluded.contains(item.stableId())) {
                        excluded.remove(item.stableId());
                    } else {
                        excluded.add(item.stableId());
                    }
                    boolean nowOff = excluded.contains(item.stableId());
                    cell.setAlpha(nowOff ? 0.35f : 1f);
                    mark.setVisibility(nowOff ? View.VISIBLE : View.GONE);
                    long bytes = 0L;
                    int count = 0;
                    for (MediaItem m : pending) {
                        if (!excluded.contains(m.stableId())) {
                            count++;
                            bytes += m.sizeBytes();
                        }
                    }
                    confirm.setText("开始同步（" + count + " 项 · " + Widgets.formatBytes(bytes) + "）");
                    confirm.setEnabled(count > 0);
                    host.onSelectionChanged(count, bytes);
                }
            });
            grid.addView(cell, params);
        }

        ScrollView scroll = new ScrollView(activity);
        scroll.addView(grid);
        page.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        LinearLayout bar = new LinearLayout(activity);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        Button cancel = widgets.smallButton("取消");
        cancel.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.onCancel();
            }
        });
        long total = 0L;
        for (MediaItem m : pending) {
            if (!excluded.contains(m.stableId())) {
                total += m.sizeBytes();
            }
        }
        confirm.setText("开始同步（" + pending.size() + " 项 · " + Widgets.formatBytes(total) + "）");
        confirm.setEnabled(!pending.isEmpty());
        confirm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.onConfirm();
            }
        });
        bar.addView(cancel);
        bar.addView(confirm, widgets.weightParams());
        page.addView(bar);
        return page;
    }
}
```

- [ ] **Step 2: MainActivity 接线**（按 Interfaces；`onBackPressed` confirm → library/home 返回）

- [ ] **Step 3: 编译测试提交**

Run: `./android/run_tests.sh && ./android/build.sh` → 通过。

```bash
git add android/src/main/java/com/androidsync/app/
git commit -m "feat: B19 同步前确认态与临时排除"
```

---

### Task 6: TransferCardView（B20 前半）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/TransferCardView.java`

**Interfaces:**
- Consumes: Task 1 `Widgets/Theme`；`core/SyncTask`（读文件名/进度/状态，访问器以实际类为准）。
- Produces: `TransferCardView`——构造 `(Activity, Widgets, RetryHandler)`，接口 `RetryHandler { void retry(String taskId); }`：
  - `View build()`：根容器（初始 `GONE`）。
  - `void showProgress(int done, int total, long bytesRemaining, String speedText)`：渐变进度卡，文案 `"接收中 done/total · 剩 " + Widgets.formatBytes(bytesRemaining)`；`speedText` 非 null 时追加。
  - `void showTodayStats(int count, long bytes)`：统计卡 `"今天已同步 count 项 · X"`。
  - `void showFailure(String message)` / `void clearFailure()`：红色横幅（`Theme.STATUS_FAILED` 12% 透明度背景）。
  - 点击卡片切换展开：`void bindTasks(List<SyncTask> active)` 填充逐文件行（文件名 + 百分比；失败行加"重试"按钮调 `RetryHandler.retry(taskId)`）。
  - `void hide()`：整体 `GONE`。

- [ ] **Step 1: 完整实现**

渐变卡背景：

```java
GradientDrawable gradient = new GradientDrawable(
        GradientDrawable.Orientation.TL_BR,
        new int[] { widgets.color(Theme.GRADIENT_START), widgets.color(Theme.GRADIENT_END) });
gradient.setCornerRadius(widgets.dp(Theme.RADIUS_L));
```

进度条 `ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal)`、`setMax(total)`、`setProgress(done)`。根容器 `LinearLayout VERTICAL`：横幅行（默认 GONE）→ 水平行（渐变进度卡 `weightParams()` + 统计卡固定宽 `dp(120)`）→ 展开列表容器（默认 GONE，`widgets.card()` 行填充）。所有 `showXxx` 方法只操作已建 View 的文本/可见性，UI 线程调用（调用方保证）。类自包含约 200 行，全部用 Theme token 与 Widgets 工厂。

- [ ] **Step 2: 编译提交**

Run: `./android/run_tests.sh && ./android/build.sh` → 通过。

```bash
git add android/src/main/java/com/androidsync/app/ui/TransferCardView.java
git commit -m "feat: B20 传输卡片行组件"
```

---

### Task 7: LibraryPageView、预览弹层与两 tab 切换（B20 后半）

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/LibraryPageView.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`

**Interfaces:**
- Consumes: Task 1–6 全部产出；现有 `SyncQueue` 状态读取、`render()` 机制、`openMedia(MediaItem)` :1560。
- Produces:
  - `LibraryPageView`：构造 `(Activity, Widgets, ThumbnailLoader)`；`View build(LibraryHost host)`；接口：

```java
public interface LibraryHost {
    List<MediaStoreScanner.Album> whitelistAlbums();   // chips 数据（白名单内相册）
    Set<String> activeChipFilter();                    // 显示过滤（bucketId 子集，空=全部显示）
    void toggleChip(String bucketId);                  // 只改显示过滤，不改白名单
    void openAlbumPicker();                            // "管理" chip
    List<MediaItem> visibleItems();                    // 白名单 ∩ chip 过滤后的扫描结果
    void openPreview(MediaItem item);
    void startConfirm();                               // FAB
    View transferCard();                               // TransferCardView.build() 根
}
```

  - 布局：`LinearLayout VERTICAL`——chips 行（`HorizontalScrollView`，选中 chip `rounded("#33E8A33D", Theme.ACCENT, 1, 10)`，未选 `rounded(Theme.BG_RAISED, Theme.STROKE, 1, 10)`；尾部"管理"chip）→ `host.transferCard()` → `FrameLayout`（三列网格 ScrollView + FAB `Button` `rounded(Theme.ACCENT, null, 0, 20)`，`FrameLayout.LayoutParams` `Gravity.BOTTOM | Gravity.END`，margin `dp(Theme.SPACE_L)`，文案 `"⇪ 同步"`，点击 `host.startConfirm()`）。网格单元格构建同 Task 5（无排除角标，点击 `host.openPreview(item)`）。
  - MainActivity：
    - `screen` 收敛为 `"library"/"settings"/"albumPicker"/"confirm"`，默认 `"library"`；`navBar()` 缩两项（媒体库/设置）。
    - **删除**（方法 + 专属字段 + 调用点）：`homeView/queueView/detailView/homeHeader/backHeader/recentGrid/recentTaskTile/shouldLoadMore/loadMoreQueueRows/refreshQueueSummary/refreshHomeSyncState/refreshHomeRecentTaskTile/refreshDetailSyncState/refreshCurrentScreenSyncState/refreshQueueRow/rebuildQueueTaskContainerPreservingScroll/populateQueueTaskContainer/updateQueueLoadMoreHint/metaRow×2/paddedTextParams/targetCard/queueSummary/filterStrip/filterButton/queueTaskList/taskList/taskRow/bindQueueRow/thumbnail(SyncTask)/statRow/stat×2/ProgressRing/QueueRowViews/RecentTaskTileViews` 与字段 :106–124（`root/scanner/screen` 等通用字段保留）。
    - 同步进度回调改driving `TransferCardView`：任务状态变化处（原 `refreshCurrentScreenSyncState` 调用点）改为聚合 `SyncQueue` 活动任务 → `showProgress(done, total, bytesRemaining, null)` + `bindTasks(active)`；全部完成 → `showTodayStats(本进程今日完成计数, 字节)` 后延时 3 秒 `hide()`（`mainHandler.postDelayed`）；失败 → `showFailure(cleanError(...))`。今日统计口径：进程内完成计数（`SyncTask` 无完成时间字段时），报告注明。
    - 预览弹层：`private void showPreview(MediaItem item)`——`new Dialog(this)` 全屏 `Theme.BG` 背景，`ImageView`（`thumbnailLoader.loadPreviewAsync`）+ 文件名/`Widgets.formatBytes(sizeBytes)`/`formatDate(dateModifiedMillis)` 三行 + 视频项 `actionButton("用系统播放器打开", -> openMedia(item))`；替代原 detailView。
    - `onBackPressed()`：confirm/albumPicker/settings → `screen = "library"; render();`；library → `super.onBackPressed()`。

- [ ] **Step 1: LibraryPageView 完整实现**（按 Interfaces；chips/FAB/网格如上）

- [ ] **Step 2: MainActivity 删旧接新**（按删除清单与回调改造）

- [ ] **Step 3: 验证**

Run: `./android/run_tests.sh && ./android/build.sh`
Expected: 通过；`grep -n "homeView\|queueView\|detailView\|ProgressRing" android/src/main/java/com/androidsync/app/MainActivity.java` 无命中；MainActivity 预期 <900 行。

- [ ] **Step 4: 提交**

```bash
git add android/src/main/java/com/androidsync/app/
git commit -m "feat: B20 媒体库首页与两 tab 结构"
```

---

### Task 8: 设备名 header 与真机 QA 清单（B21）

**Files:**
- Modify: `android/src/main/java/com/androidsync/app/android/HttpFileUploader.java`

**Interfaces:**
- Consumes: B16 修复后的 upload 头设置区。
- Produces: 请求头 `X-Android-Sync-Device`（值 `android.os.Build.MODEL`）。

- [ ] **Step 1: 加头**

`connection.setRequestProperty("X-Android-Sync-Size", ...)` 行后加：

```java
        connection.setRequestProperty("X-Android-Sync-Device", android.os.Build.MODEL);
```

- [ ] **Step 2: 编译测试提交**

Run: `./android/run_tests.sh && ./android/build.sh` → 通过。

```bash
git add android/src/main/java/com/androidsync/app/android/HttpFileUploader.java
git commit -m "feat: B21 上传请求带设备型号头"
```

- [ ] **Step 3: 真机 QA 清单（控制器/用户执行；无设备时批次记录为未验证，B21 不宣称关闭）**

1. 首启：权限 → 相册引导（预勾 Camera）→ 至少选一个才能完成。
2. 白名单外媒体（Download 电影）不出现在网格与确认态。
3. chips 过滤只影响显示；管理页增删相册后网格随之变化。
4. 确认态排除 2 项 → 上传数量与字节吻合；排除项未上传。
5. 传输中卡片行进度/展开逐文件/失败重试；完成显示今日统计后收起。
6. GB 级视频传输全程不崩溃、内存平稳（B16 回归）。
7. macOS 端收到 `X-Android-Sync-Device` 头（抓包或 macOS 后续读取批次验证）。
8. 弹层预览：图片显示、视频跳系统播放器；返回键路径正确（confirm/设置/相册页回 library）。
