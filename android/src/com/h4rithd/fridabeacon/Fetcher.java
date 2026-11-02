package com.h4rithd.fridabeacon;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import javax.net.ssl.HttpsURLConnection;
import org.json.JSONArray;
import org.json.JSONObject;

/** HTTPS downloader used by the module on Android without a curl dependency. */
public final class Fetcher {
    private static final String API = "https://api.github.com/repos/frida/frida/releases/latest";
    private static final String USER_AGENT = "FridaBeacon/1.0";

    private static HttpsURLConnection open(String address) throws Exception {
        URL url = new URL(address);
        if (!"https".equals(url.getProtocol())) {
            throw new IllegalArgumentException("HTTPS is required");
        }
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        if (!(connection instanceof HttpsURLConnection)) {
            throw new IllegalArgumentException("HTTPS connection is required");
        }
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(60000);
        connection.setInstanceFollowRedirects(true);
        connection.setRequestProperty("User-Agent", USER_AGENT);
        connection.setRequestProperty("Accept", "application/vnd.github+json");
        if (connection.getResponseCode() != 200) {
            throw new IllegalStateException("HTTP " + connection.getResponseCode());
        }
        return (HttpsURLConnection) connection;
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) {
            result.append(Character.forDigit((value >> 4) & 15, 16));
            result.append(Character.forDigit(value & 15, 16));
        }
        return result.toString();
    }

    private static void metadata(String arch) throws Exception {
        HttpsURLConnection connection = open(API);
        byte[] bytes;
        try (InputStream input = connection.getInputStream();
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] chunk = new byte[16384];
            int count;
            while ((count = input.read(chunk)) != -1) {
                output.write(chunk, 0, count);
            }
            bytes = output.toByteArray();
        } finally {
            connection.disconnect();
        }
        JSONObject release = new JSONObject(new String(bytes, "UTF-8"));
        String version = release.getString("tag_name");
        if (!version.matches("[0-9]+\\.[0-9]+\\.[0-9]+")) {
            throw new IllegalStateException("Unexpected release version");
        }
        String target = "frida-server-" + version + "-android-" + arch + ".xz";
        JSONArray assets = release.getJSONArray("assets");
        for (int index = 0; index < assets.length(); index++) {
            JSONObject asset = assets.getJSONObject(index);
            if (target.equals(asset.getString("name"))) {
                String digest = asset.getString("digest");
                if (!digest.matches("sha256:[0-9a-f]{64}")) {
                    throw new IllegalStateException("Missing official SHA-256 digest");
                }
                System.out.println(version + " " + digest.substring(7));
                return;
            }
        }
        throw new IllegalStateException("No Android server asset for " + arch);
    }

    private static void fetch(String arch, String version, String digest, File output) throws Exception {
        if (!version.matches("[0-9]+\\.[0-9]+\\.[0-9]+") ||
                !digest.matches("[0-9a-f]{64}")) {
            throw new IllegalArgumentException("Invalid release metadata");
        }
        String asset = "frida-server-" + version + "-android-" + arch + ".xz";
        String address = "https://github.com/frida/frida/releases/download/" + version + "/" + asset;
        MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
        HttpsURLConnection connection = open(address);
        try (InputStream input = connection.getInputStream();
             FileOutputStream file = new FileOutputStream(output)) {
            byte[] chunk = new byte[16384];
            int count;
            while ((count = input.read(chunk)) != -1) {
                file.write(chunk, 0, count);
                sha256.update(chunk, 0, count);
            }
        } catch (Exception error) {
            output.delete();
            throw error;
        } finally {
            connection.disconnect();
        }
        if (!digest.equals(hex(sha256.digest()))) {
            output.delete();
            throw new IllegalStateException("Official release SHA-256 mismatch");
        }
        System.out.println("Verified " + asset);
    }

    public static void main(String[] args) {
        try {
            if (args.length < 2 || !args[1].matches("arm|arm64|x86|x86_64")) {
                throw new IllegalArgumentException("Usage: Fetcher metadata ARCH | fetch ARCH VERSION SHA256 OUTPUT");
            }
            if ("metadata".equals(args[0]) && args.length == 2) {
                metadata(args[1]);
            } else if ("fetch".equals(args[0]) && args.length == 5) {
                fetch(args[1], args[2], args[3], new File(args[4]));
            } else {
                throw new IllegalArgumentException("Invalid arguments");
            }
        } catch (Exception error) {
            System.err.println("FridaBeacon: " + error.getMessage());
            System.exit(1);
        }
    }
}
