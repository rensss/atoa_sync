package com.androidsync.app.ui;

import android.app.Activity;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.BaseAdapter;
import android.widget.FrameLayout;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.TextView;

import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncStatus;

import java.util.List;
import java.util.Map;

/** Recycles square thumbnail cells while keeping thumbnail identity checks in ThumbnailLoader. */
public final class MediaGridAdapter extends BaseAdapter {
    public interface ItemClickListener {
        void onItemClick(MediaItem item);
    }

    private static final int FALLBACK_CELL_DP = 112;

    private final Activity activity;
    private final Widgets widgets;
    private final ThumbnailLoader thumbnails;
    private final ItemClickListener itemClickListener;
    private final MediaGridData data = new MediaGridData();

    private GridView observedGrid;
    private View.OnLayoutChangeListener pendingMeasureListener;
    private int cellSizePixels;

    public MediaGridAdapter(Activity activity, Widgets widgets, ThumbnailLoader thumbnails, ItemClickListener listener) {
        this.activity = activity;
        this.widgets = widgets;
        this.thumbnails = thumbnails;
        this.itemClickListener = listener;
    }

    public void replaceItems(List<MediaItem> items) {
        data.replaceItems(items);
        notifyDataSetChanged();
    }

    public void replaceStatuses(Map<String, SyncStatus> statuses) {
        data.replaceStatuses(statuses);
        notifyDataSetChanged();
    }

    public int clampPosition(int position) {
        return data.clampPosition(position);
    }

    @Override
    public int getCount() {
        return data.getCount();
    }

    @Override
    public MediaItem getItem(int position) {
        return data.getItem(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        final MediaItem item = getItem(position);
        GridCell cell = convertView instanceof GridCell ? (GridCell) convertView : new GridCell(activity);
        int measured = measuredCellSize(parent);
        if (measured > 0) {
            cellSizePixels = measured;
        } else if (parent instanceof GridView) {
            watchForGridMeasurement((GridView) parent);
        }
        int height = cellSizePixels > 0 ? cellSizePixels : widgets.dp(FALLBACK_CELL_DP);
        cell.setLayoutParams(new AbsListView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height));

        cell.image.setTag(item.uri());
        cell.placeholder.setText(item.isVideo() ? "视频" : "照片");
        cell.badge.setText(statusText(data.statusFor(item)));
        applyStatusStyle(cell.badge, data.statusFor(item));
        cell.setContentDescription(item.displayName() + "，" + statusText(data.statusFor(item)));
        cell.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (itemClickListener != null) {
                    itemClickListener.onItemClick(item);
                }
            }
        });

        int requestSize = cellSizePixels > 0 ? cellSizePixels : height;
        thumbnails.loadThumbnailInto(cell.image, cell.placeholder, item.uri(), requestSize);
        return cell;
    }

    private int measuredCellSize(ViewGroup parent) {
        if (!(parent instanceof GridView)) {
            return 0;
        }
        GridView grid = (GridView) parent;
        int columnWidth = grid.getColumnWidth();
        if (columnWidth > 0) {
            return columnWidth;
        }
        int columns = grid.getNumColumns();
        if (columns <= 0 || grid.getWidth() <= 0) {
            return 0;
        }
        int available = grid.getWidth() - grid.getPaddingLeft() - grid.getPaddingRight()
                - grid.getHorizontalSpacing() * (columns - 1);
        return Math.max(0, available / columns);
    }

    private void watchForGridMeasurement(final GridView grid) {
        if (pendingMeasureListener != null && observedGrid == grid) {
            return;
        }
        if (pendingMeasureListener != null && observedGrid != null) {
            observedGrid.removeOnLayoutChangeListener(pendingMeasureListener);
        }
        observedGrid = grid;
        pendingMeasureListener = new View.OnLayoutChangeListener() {
            @Override
            public void onLayoutChange(View view, int left, int top, int right, int bottom,
                    int oldLeft, int oldTop, int oldRight, int oldBottom) {
                int measured = measuredCellSize(grid);
                if (measured > 0) {
                    grid.removeOnLayoutChangeListener(this);
                    pendingMeasureListener = null;
                    cellSizePixels = measured;
                    notifyDataSetChanged();
                }
            }
        };
        grid.addOnLayoutChangeListener(pendingMeasureListener);
    }

    private String statusText(SyncStatus status) {
        switch (status) {
            case DONE:
                return "已同步";
            case UPLOADING:
                return "上传中";
            case FAILED:
                return "失败";
            case WAITING:
            default:
                return "未同步";
        }
    }

    private void applyStatusStyle(TextView badge, SyncStatus status) {
        String fill;
        String stroke;
        String text;
        switch (status) {
            case DONE:
                fill = "#CC1C3D2C";
                stroke = Theme.STATUS_RUNNING;
                text = Theme.STATUS_RUNNING;
                break;
            case UPLOADING:
                fill = "#CC183039";
                stroke = Theme.ACCENT;
                text = Theme.ACCENT;
                break;
            case FAILED:
                fill = "#CC3B2326";
                stroke = Theme.STATUS_FAILED;
                text = Theme.STATUS_FAILED;
                break;
            case WAITING:
            default:
                fill = "#CC1A2027";
                stroke = Theme.STROKE;
                text = Theme.TEXT_PRIMARY;
                break;
        }
        badge.setTextColor(widgets.color(text));
        badge.setBackground(widgets.rounded(fill, stroke, 1, Theme.RADIUS_S));
    }

    private final class GridCell extends FrameLayout {
        private final ImageView image;
        private final TextView placeholder;
        private final TextView badge;

        GridCell(Activity activity) {
            super(activity);
            setBackground(widgets.rounded(Theme.BG_RAISED, Theme.STROKE, 1, Theme.RADIUS_S));
            setClipToOutline(true);
            image = new ImageView(activity);
            image.setScaleType(ImageView.ScaleType.CENTER_CROP);
            image.setBackgroundColor(widgets.color(Theme.BG_RAISED));
            addView(image, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

            placeholder = widgets.label("照片", 12, Theme.TEXT_SECONDARY);
            placeholder.setGravity(Gravity.CENTER);
            addView(placeholder, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

            badge = widgets.label("未同步", 10, Theme.TEXT_PRIMARY);
            badge.setGravity(Gravity.CENTER);
            badge.setPadding(widgets.dp(Theme.SPACE_S), widgets.dp(2), widgets.dp(Theme.SPACE_S), widgets.dp(2));
            FrameLayout.LayoutParams badgeParams = new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            badgeParams.gravity = Gravity.TOP | Gravity.END;
            badgeParams.setMargins(0, widgets.dp(Theme.SPACE_S), widgets.dp(Theme.SPACE_S), 0);
            addView(badge, badgeParams);
            setClickable(true);
            setFocusable(true);
        }
    }
}
