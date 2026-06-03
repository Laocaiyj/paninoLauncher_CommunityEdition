package dev.panino.companion;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class PaninoCompanionClient {
    private static final int MAX_SAMPLES = 600;
    private static final ArrayDeque<Double> FRAME_TIMES_MS = new ArrayDeque<>();

    private PaninoCompanionClient() {
    }

    public static void recordFrame(long frameNanos) {
        synchronized (FRAME_TIMES_MS) {
            if (FRAME_TIMES_MS.size() >= MAX_SAMPLES) {
                FRAME_TIMES_MS.removeFirst();
            }
            FRAME_TIMES_MS.addLast(frameNanos / 1_000_000.0);
        }
    }

    public static void flushSample(String endpoint, String launchSessionId, String token, String gameDir, boolean worldLoaded, boolean shaderActive, String dimension) throws Exception {
        List<Double> samples;
        synchronized (FRAME_TIMES_MS) {
            samples = new ArrayList<>(FRAME_TIMES_MS);
            FRAME_TIMES_MS.clear();
        }
        if (samples.isEmpty()) {
            return;
        }

        Collections.sort(samples);
        String payload = "{"
            + "\"gameDir\":\"" + escape(gameDir) + "\","
            + "\"launchSessionId\":\"" + escape(launchSessionId) + "\","
            + "\"frame\":{"
            + "\"frameTimeP50Ms\":" + percentile(samples, 0.50) + ","
            + "\"frameTimeP95Ms\":" + percentile(samples, 0.95) + ","
            + "\"frameTimeP99Ms\":" + percentile(samples, 0.99) + ","
            + "\"fpsAverage\":" + fpsAverage(samples) + ","
            + "\"stutterCount\":" + stutterCount(samples) + ","
            + "\"dimension\":\"" + escape(dimension) + "\","
            + "\"shaderActive\":" + shaderActive + ","
            + "\"worldLoaded\":" + worldLoaded
            + "}}";

        HttpURLConnection connection = (HttpURLConnection) new URL(endpoint + "/api/v1/performance/session/sample").openConnection();
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type", "application/json");
        if (token != null && !token.isEmpty()) {
            connection.setRequestProperty("Authorization", "Bearer " + token);
        }
        connection.setDoOutput(true);
        try (OutputStream stream = connection.getOutputStream()) {
            stream.write(payload.getBytes(StandardCharsets.UTF_8));
        }
        connection.getResponseCode();
        connection.disconnect();
    }

    private static double percentile(List<Double> samples, double percentile) {
        int index = Math.min(samples.size() - 1, Math.max(0, (int) Math.ceil(samples.size() * percentile) - 1));
        return samples.get(index);
    }

    private static double fpsAverage(List<Double> samples) {
        double total = 0;
        for (double sample : samples) {
            total += sample;
        }
        double meanFrameMs = total / samples.size();
        return meanFrameMs <= 0 ? 0 : 1000.0 / meanFrameMs;
    }

    private static int stutterCount(List<Double> samples) {
        int count = 0;
        for (double sample : samples) {
            if (sample >= 50.0) {
                count++;
            }
        }
        return count;
    }

    private static String escape(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
