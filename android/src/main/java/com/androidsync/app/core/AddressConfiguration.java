package com.androidsync.app.core;

import java.net.URI;
import java.net.URLDecoder;

/** Parses the app link embedded in the macOS receiver address QR code. */
public final class AddressConfiguration {
    private static final String LINK_SCHEME = "androidsync";
    private static final String LINK_HOST = "configure";

    private AddressConfiguration() {
    }

    public static String targetUrlFromDeepLink(String deepLink) {
        if (deepLink == null || deepLink.trim().isEmpty()) {
            return null;
        }
        try {
            URI link = new URI(deepLink.trim());
            if (!LINK_SCHEME.equalsIgnoreCase(link.getScheme())
                    || !LINK_HOST.equalsIgnoreCase(link.getHost())) {
                return null;
            }
            String rawQuery = link.getRawQuery();
            if (rawQuery == null) {
                return null;
            }
            for (String pair : rawQuery.split("&")) {
                int separator = pair.indexOf('=');
                if (separator <= 0) {
                    continue;
                }
                String name = URLDecoder.decode(pair.substring(0, separator), "UTF-8");
                if (!"url".equals(name)) {
                    continue;
                }
                String candidate = URLDecoder.decode(pair.substring(separator + 1), "UTF-8").trim();
                return isSupportedTarget(candidate) ? candidate : null;
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }

    static boolean isSupportedTarget(String candidate) {
        if (candidate == null || candidate.isEmpty()) {
            return false;
        }
        try {
            URI target = new URI(candidate);
            String scheme = target.getScheme();
            return ("http".equalsIgnoreCase(scheme) || "https".equalsIgnoreCase(scheme))
                    && target.getHost() != null
                    && !target.getHost().isEmpty();
        } catch (Exception ignored) {
            return false;
        }
    }
}
