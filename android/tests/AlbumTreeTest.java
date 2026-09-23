import com.androidsync.app.core.AlbumTree;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class AlbumTreeTest {
    public static void main(String[] args) {
        testBuildsNestedFoldersAndCountsDescendants();
        testFolderSelectionCascadesAndShowsPartialState();
        testCanToggleDirectAlbumWithoutItsChildFolders();
        testMissingPathsRemainFlatAtRoot();
        System.out.println("AlbumTreeTest passed");
    }

    private static void testBuildsNestedFoldersAndCountsDescendants() {
        AlbumTree.Node root = AlbumTree.build(Arrays.asList(
                album("camera", "Camera", 3, "DCIM/Camera/"),
                album("trip", "Trip", 5, "Pictures/Trips/2026"),
                album("raw", "RAW", 2, "DCIM/Camera/RAW")
        ));

        assertEquals(2, root.children.size());
        AlbumTree.Node dcim = root.find("DCIM");
        assertNotNull(dcim);
        assertEquals(5, dcim.totalCount);
        assertEquals(1, dcim.children.size());
        assertEquals(1, dcim.find("DCIM/Camera").children.size());
        assertEquals(2, dcim.find("DCIM/Camera/RAW").totalCount);
    }

    private static void testFolderSelectionCascadesAndShowsPartialState() {
        AlbumTree.Node root = AlbumTree.build(Arrays.asList(
                album("camera", "Camera", 3, "DCIM/Camera"),
                album("raw", "RAW", 2, "DCIM/Camera/RAW"),
                album("other", "Other", 1, "DCIM/Other"),
                album("screenshots", "Screenshots", 4, "Pictures/Screenshots")
        ));
        AlbumTree.Node dcim = root.find("DCIM");
        AlbumTree.Node camera = root.find("DCIM/Camera");
        Set<String> selected = new HashSet<>();

        camera.toggle(selected);
        assertEquals(setOf("camera", "raw"), selected);
        assertEquals(AlbumTree.CheckState.ALL, camera.checkState(selected));
        assertEquals(AlbumTree.CheckState.PARTIAL, dcim.checkState(selected));

        dcim.toggle(selected);
        assertEquals(AlbumTree.CheckState.ALL, dcim.checkState(selected));
        assertEquals(setOf("camera", "raw", "other"), selected);

        root.find("DCIM/Camera/RAW").toggle(selected);
        assertEquals(AlbumTree.CheckState.PARTIAL, camera.checkState(selected));
        assertEquals(AlbumTree.CheckState.PARTIAL, dcim.checkState(selected));
    }

    private static void testMissingPathsRemainFlatAtRoot() {
        List<AlbumTree.Album> albums = new ArrayList<>();
        albums.add(album("unknown-a", "Downloads", 7, null));
        albums.add(album("unknown-b", "Downloads", 2, "  /  "));
        AlbumTree.Node root = AlbumTree.build(albums);

        assertEquals(0, root.children.size());
        assertEquals(2, root.fallbackAlbums.size());
        assertEquals(AlbumTree.CheckState.NONE, root.checkState(new HashSet<String>()));
    }

    private static void testCanToggleDirectAlbumWithoutItsChildFolders() {
        AlbumTree.Node root = AlbumTree.build(Arrays.asList(
                album("camera", "Camera", 3, "DCIM/Camera"),
                album("raw", "RAW", 2, "DCIM/Camera/RAW")
        ));
        AlbumTree.Node camera = root.find("DCIM/Camera");
        Set<String> selected = new HashSet<>();

        camera.toggle(selected);
        camera.toggle(camera.directAlbums.get(0), selected);

        assertEquals(setOf("raw"), selected);
        assertEquals(AlbumTree.CheckState.PARTIAL, camera.checkState(selected));
    }

    private static AlbumTree.Album album(String id, String name, int count, String path) {
        return new AlbumTree.Album(id, name, count, path);
    }

    private static Set<String> setOf(String... values) {
        return new HashSet<>(Arrays.asList(values));
    }

    private static void assertNotNull(Object value) {
        if (value == null) {
            throw new AssertionError("expected non-null value");
        }
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }

    private static void assertEquals(int expected, int actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
