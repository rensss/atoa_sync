package com.androidsync.app.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Platform-independent folder tree and cascading album selection state. */
public final class AlbumTree {
    public enum CheckState {
        NONE,
        PARTIAL,
        ALL
    }

    public static final class Album {
        public final String bucketId;
        public final String name;
        public final int count;
        public final String path;

        public Album(String bucketId, String name, int count, String path) {
            this.bucketId = bucketId;
            this.name = name;
            this.count = count;
            this.path = path;
        }
    }

    public static final class Node {
        public final String path;
        public final String name;
        public final List<Node> children;
        public final List<Album> directAlbums;
        /** Albums whose provider did not expose a usable directory path; keep them flat at root. */
        public final List<Album> fallbackAlbums;
        public final int totalCount;

        private final Set<String> bucketIds;

        private Node(String path, String name, List<Node> children, List<Album> directAlbums,
                     List<Album> fallbackAlbums) {
            this.path = path;
            this.name = name;
            this.children = Collections.unmodifiableList(children);
            this.directAlbums = Collections.unmodifiableList(directAlbums);
            this.fallbackAlbums = Collections.unmodifiableList(fallbackAlbums);

            LinkedHashSet<String> ids = new LinkedHashSet<>();
            int count = 0;
            for (Album album : directAlbums) {
                ids.add(album.bucketId);
                count += album.count;
            }
            for (Album album : fallbackAlbums) {
                ids.add(album.bucketId);
                count += album.count;
            }
            for (Node child : children) {
                ids.addAll(child.bucketIds);
                count += child.totalCount;
            }
            this.bucketIds = Collections.unmodifiableSet(ids);
            this.totalCount = count;
        }

        public Node find(String wantedPath) {
            String normalized = normalizePath(wantedPath);
            if (normalized.isEmpty()) {
                return path.isEmpty() ? this : null;
            }
            if (!path.isEmpty() && normalized.equals(path)) {
                return this;
            }
            if (!path.isEmpty() && !normalized.startsWith(path + "/")) {
                return null;
            }
            String remaining = path.isEmpty() ? normalized : normalized.substring(path.length() + 1);
            int slash = remaining.indexOf('/');
            String nextName = slash < 0 ? remaining : remaining.substring(0, slash);
            for (Node child : children) {
                if (child.name.equals(nextName)) {
                    return slash < 0 ? child : child.find(normalized);
                }
            }
            return null;
        }

        public CheckState checkState(Set<String> selectedBucketIds) {
            if (bucketIds.isEmpty()) {
                return CheckState.NONE;
            }
            int selectedCount = 0;
            for (String bucketId : bucketIds) {
                if (selectedBucketIds.contains(bucketId)) {
                    selectedCount++;
                }
            }
            if (selectedCount == 0) {
                return CheckState.NONE;
            }
            return selectedCount == bucketIds.size() ? CheckState.ALL : CheckState.PARTIAL;
        }

        /** A partial folder click completes the selection; a fully selected folder clears it. */
        public void toggle(Set<String> selectedBucketIds) {
            if (checkState(selectedBucketIds) == CheckState.ALL) {
                selectedBucketIds.removeAll(bucketIds);
            } else {
                selectedBucketIds.addAll(bucketIds);
            }
        }

        public CheckState checkState(Album album, Set<String> selectedBucketIds) {
            return selectedBucketIds.contains(album.bucketId) ? CheckState.ALL : CheckState.NONE;
        }

        public void toggle(Album album, Set<String> selectedBucketIds) {
            if (!selectedBucketIds.remove(album.bucketId)) {
                selectedBucketIds.add(album.bucketId);
            }
        }
    }

    public static Node build(List<Album> albums) {
        MutableNode root = new MutableNode("", "");
        for (Album album : albums) {
            if (album == null || album.bucketId == null || album.bucketId.isEmpty()) {
                continue;
            }
            String normalizedPath = normalizePath(album.path);
            if (normalizedPath.isEmpty()) {
                root.fallbackAlbums.add(album);
                continue;
            }
            MutableNode current = root;
            StringBuilder currentPath = new StringBuilder();
            String[] segments = normalizedPath.split("/");
            for (String segment : segments) {
                if (currentPath.length() > 0) {
                    currentPath.append('/');
                }
                currentPath.append(segment);
                String key = currentPath.toString();
                MutableNode child = current.children.get(segment);
                if (child == null) {
                    child = new MutableNode(key, segment);
                    current.children.put(segment, child);
                }
                current = child;
            }
            current.directAlbums.add(album);
        }
        return freeze(root);
    }

    public static String normalizePath(String path) {
        if (path == null || path.trim().isEmpty()) {
            return "";
        }
        String[] parts = path.trim().replace('\\', '/').split("/");
        StringBuilder normalized = new StringBuilder();
        for (String part : parts) {
            if (part.isEmpty() || ".".equals(part)) {
                continue;
            }
            if (normalized.length() > 0) {
                normalized.append('/');
            }
            normalized.append(part);
        }
        return normalized.toString();
    }

    private static Node freeze(MutableNode source) {
        List<Node> children = new ArrayList<>();
        for (MutableNode child : source.children.values()) {
            children.add(freeze(child));
        }
        Collections.sort(children, new Comparator<Node>() {
            @Override
            public int compare(Node left, Node right) {
                return String.CASE_INSENSITIVE_ORDER.compare(left.name, right.name);
            }
        });
        return new Node(source.path, source.name, children, source.directAlbums, source.fallbackAlbums);
    }

    private static final class MutableNode {
        private final String path;
        private final String name;
        private final Map<String, MutableNode> children = new LinkedHashMap<>();
        private final List<Album> directAlbums = new ArrayList<>();
        private final List<Album> fallbackAlbums = new ArrayList<>();

        private MutableNode(String path, String name) {
            this.path = path;
            this.name = name;
        }
    }

    private AlbumTree() {
    }
}
