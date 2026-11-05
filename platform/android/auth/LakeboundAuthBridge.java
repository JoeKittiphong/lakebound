package com.godot.game;

import android.content.Intent;
import android.net.Uri;
import androidx.annotation.Keep;

/** Only a one-use authorization code crosses this bridge. Never log the URI. */
@Keep
public final class LakeboundAuthBridge {
    private static String callback = "";
    private LakeboundAuthBridge() {}

    public static synchronized void capture(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction())) return;
        Uri uri = intent.getData();
        if (uri == null || !"com.zylaah.lakebound".equals(uri.getScheme())
                || !"auth".equals(uri.getHost()) || !"/callback".equals(uri.getPath())) return;
        String code = uri.getQueryParameter("code");
        if (code == null || code.length() < 8 || code.length() > 2048) return;
        callback = uri.toString();
        intent.setData(null);
    }

    @Keep
    public static synchronized String consumeCallback() {
        String result = callback;
        callback = "";
        return result;
    }
}
