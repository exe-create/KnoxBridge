package zombie;

import java.util.ArrayList;
import java.util.List;

/** API-shaped fixture: PZ declares List while callers may provide ArrayList. */
public final class ZomboidFileSystem {
    private final List<String> loaded = new ArrayList<>();
    public void loadMods(List<String> ids) { loaded.clear(); loaded.addAll(ids); }
    public List<String> getModIDs() { return loaded; }
    public String getModDir(String id) { return id; }
    public Object getModInfoForDir(String dir) { return null; }
}
