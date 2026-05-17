package com.dmkr.audio;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.media.MediaRecorder;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final int REQUEST_RECORD_AUDIO = 10;

    private MediaRecorder recorder;
    private File currentFile;
    private long startedAt;
    private TextView statusText;
    private TextView timerText;
    private LinearLayout recordingsList;
    private Button recordButton;
    private boolean recording;

    private final Runnable timerTick = new Runnable() {
        @Override
        public void run() {
            if (!recording) return;
            long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
            timerText.setText(String.format(Locale.US, "%02d:%02d", seconds / 60, seconds % 60));
            timerText.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(buildUi());
        refreshRecordings();
    }

    private View buildUi() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(36, 42, 36, 36);
        root.setBackgroundColor(0xFFF5F7FB);
        scroll.addView(root);

        TextView title = new TextView(this);
        title.setText("AudioRecorder");
        title.setTextSize(34);
        title.setTextColor(0xFF182233);
        title.setGravity(Gravity.START);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText("Graba audio y guarda segmentos locales en Android.");
        subtitle.setTextSize(16);
        subtitle.setTextColor(0xFF667085);
        subtitle.setPadding(0, 8, 0, 28);
        root.addView(subtitle);

        statusText = new TextView(this);
        statusText.setText("Listo para grabar");
        statusText.setTextSize(18);
        statusText.setTextColor(0xFF182233);
        root.addView(statusText);

        timerText = new TextView(this);
        timerText.setText("00:00");
        timerText.setTextSize(54);
        timerText.setTextColor(0xFF1F6FEB);
        timerText.setTypeface(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD);
        timerText.setPadding(0, 16, 0, 20);
        root.addView(timerText);

        recordButton = new Button(this);
        recordButton.setText("Empezar grabacion");
        recordButton.setAllCaps(false);
        recordButton.setTextSize(18);
        recordButton.setOnClickListener(v -> toggleRecording());
        root.addView(recordButton);

        TextView listTitle = new TextView(this);
        listTitle.setText("Grabaciones");
        listTitle.setTextSize(24);
        listTitle.setTextColor(0xFF182233);
        listTitle.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        listTitle.setPadding(0, 36, 0, 12);
        root.addView(listTitle);

        recordingsList = new LinearLayout(this);
        recordingsList.setOrientation(LinearLayout.VERTICAL);
        root.addView(recordingsList);
        return scroll;
    }

    private void toggleRecording() {
        if (recording) {
            stopRecording();
            return;
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQUEST_RECORD_AUDIO);
            return;
        }
        startRecording();
    }

    private void startRecording() {
        File dir = recordingsDir();
        String stamp = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date());
        currentFile = new File(dir, "audio-" + stamp + ".m4a");

        recorder = new MediaRecorder();
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        recorder.setAudioEncodingBitRate(128000);
        recorder.setAudioSamplingRate(44100);
        recorder.setOutputFile(currentFile.getAbsolutePath());
        try {
            recorder.prepare();
            recorder.start();
            recording = true;
            startedAt = SystemClock.elapsedRealtime();
            statusText.setText("Grabando: " + currentFile.getName());
            recordButton.setText("Parar grabacion");
            timerText.post(timerTick);
        } catch (IOException | RuntimeException error) {
            statusText.setText("No se pudo iniciar la grabacion");
            releaseRecorder();
        }
    }

    private void stopRecording() {
        try {
            recorder.stop();
        } catch (RuntimeException ignored) {
            if (currentFile != null) currentFile.delete();
        }
        releaseRecorder();
        recording = false;
        recordButton.setText("Empezar grabacion");
        statusText.setText("Grabacion guardada");
        timerText.setText("00:00");
        refreshRecordings();
    }

    private void releaseRecorder() {
        if (recorder != null) {
            recorder.release();
            recorder = null;
        }
    }

    private File recordingsDir() {
        File dir = new File(getFilesDir(), "recordings");
        if (!dir.exists()) dir.mkdirs();
        return dir;
    }

    private void refreshRecordings() {
        recordingsList.removeAllViews();
        File[] files = recordingsDir().listFiles((dir, name) -> name.endsWith(".m4a"));
        if (files == null || files.length == 0) {
            TextView empty = new TextView(this);
            empty.setText("Aun no hay grabaciones.");
            empty.setTextSize(16);
            empty.setTextColor(0xFF667085);
            recordingsList.addView(empty);
            return;
        }

        Arrays.sort(files, (a, b) -> Long.compare(b.lastModified(), a.lastModified()));
        for (File file : files) {
            TextView row = new TextView(this);
            row.setText(file.getName() + "  ·  " + Math.max(1, file.length() / 1024) + " KB");
            row.setTextSize(16);
            row.setTextColor(0xFF182233);
            row.setPadding(0, 10, 0, 10);
            recordingsList.addView(row);
        }
    }

    @Override
    protected void onDestroy() {
        if (recording) stopRecording();
        super.onDestroy();
    }
}
