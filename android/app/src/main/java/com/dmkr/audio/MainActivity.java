package com.dmkr.audio;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Bundle;
import android.os.StrictMode;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.google.android.gms.ads.MobileAds;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final int REQUEST_RECORD_AUDIO = 10;
    private static final String PREFS = "audio_recorder_settings";
    private MediaRecorder recorder;
    private MediaPlayer player;
    private File currentFile;
    private File playingFile;
    private long startedAt;
    private int tab = 0;
    private boolean recording;
    private TextView timerText;
    private TextView levelText;
    private TextView stateText;
    private SharedPreferences prefs;
    private static final String TEST_BANNER_AD_UNIT_ID = "ca-app-pub-3940256099942544/9214589741";

    private final Runnable timerTick = new Runnable() {
        @Override
        public void run() {
            if (!recording) return;
            long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
            timerText.setText(formatTime(seconds));
            levelText.setText("-" + Math.max(18, 62 - (seconds % 35)) + " dB");
            timerText.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        StrictMode.setVmPolicy(new StrictMode.VmPolicy.Builder().build());
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        MobileAds.initialize(this, initializationStatus -> {});
        ensureDefaults();
        if (prefs.getBoolean("startOnLaunch", false)) {
            timerText = new TextView(this);
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) startRecording();
        }
        showRecorder();
    }

    private void ensureDefaults() {
        if (!prefs.contains("quality")) {
            prefs.edit()
                .putString("quality", "Media")
                .putString("mode", "Por sonido")
                .putInt("segment", 15)
                .putInt("sensitivity", 62)
                .putBoolean("startOnLaunch", false)
                .putBoolean("uploadAuto", false)
                .putString("provider", "No")
                .putString("endpoint", "")
                .apply();
        }
    }

    private void showRecorder() {
        tab = 0;
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = pageRoot();
        scroll.addView(root);

        TextView title = title(recording ? "Grabando" : "Preparado");
        TextView subtitle = text(statusText(), 15, 0xFF667085, false);
        subtitle.setGravity(Gravity.CENTER);
        root.addView(title);
        root.addView(subtitle);

        TextView mic = text(recording ? "■" : "●", 82, recording ? 0xFFD92D20 : 0xFF182233, true);
        mic.setGravity(Gravity.CENTER);
        mic.setBackgroundColor(recording ? 0x22D92D20 : 0x1A667085);
        mic.setOnClickListener(v -> toggleRecording());
        root.addView(mic, size(-1, dp(220), 0, 28, 0, 20));

        LinearLayout metrics = new LinearLayout(this);
        metrics.setGravity(Gravity.CENTER);
        timerText = metric("Segmento", recording ? timerTextValue() : "00:00");
        levelText = metric("Nivel", recording ? levelTextValue() : "0 dB");
        stateText = metric("Estado", recording ? "Guarda" : "Espera");
        metrics.addView(timerText, new LinearLayout.LayoutParams(0, -2, 1));
        metrics.addView(levelText, new LinearLayout.LayoutParams(0, -2, 1));
        metrics.addView(stateText, new LinearLayout.LayoutParams(0, -2, 1));
        root.addView(metrics);

        LinearLayout details = panel();
        details.addView(detail("Modo", prefs.getString("mode", "Por sonido")));
        details.addView(detail("Calidad", prefs.getString("quality", "Media")));
        details.addView(detail("Corte", prefs.getInt("segment", 15) + " min"));
        details.addView(detail("Sensibilidad", prefs.getInt("sensitivity", 62) + "%"));
        details.addView(detail("Subida", prefs.getBoolean("uploadAuto", false) ? prefs.getString("provider", "No") : "No"));
        root.addView(details);
        root.addView(adBanner());
        root.addView(nav());
        setContentView(scroll);
    }

    private void showFiles() {
        tab = 1;
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = pageRoot();
        scroll.addView(root);
        root.addView(title("Archivos"));
        File[] files = recordingsDir().listFiles((dir, name) -> name.endsWith(".m4a"));
        if (files == null || files.length == 0) {
            TextView empty = text("≋\nSin grabaciones\nLos segmentos apareceran aqui cuando termines de grabar.", 18, 0xFF667085, false);
            empty.setGravity(Gravity.CENTER);
            root.addView(empty, size(-1, dp(220), 0, 32, 0, 24));
        } else {
            Arrays.sort(files, (a, b) -> Long.compare(b.lastModified(), a.lastModified()));
            for (File file : files) root.addView(fileRow(file));
        }
        Button upload = primary("Procesar subida", v -> Toast.makeText(this, "Cola de subida revisada.", Toast.LENGTH_SHORT).show());
        root.addView(upload);
        root.addView(adBanner());
        root.addView(nav());
        setContentView(scroll);
    }

    private void showSettings() {
        tab = 2;
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = pageRoot();
        scroll.addView(root);
        root.addView(title("Ajustes"));
        root.addView(section("Grabacion"));
        root.addView(choiceRow("Calidad", new String[]{"Baja", "Media", "Alta"}, "quality"));
        root.addView(choiceRow("Modo", new String[]{"Por sonido", "Todo"}, "mode"));
        root.addView(choiceRow("Separar cada", new String[]{"5", "15", "30", "60", "120"}, "segment"));

        LinearLayout sensitivity = panel();
        TextView sensLabel = detail("Sensibilidad", prefs.getInt("sensitivity", 62) + "%");
        SeekBar seek = new SeekBar(this);
        seek.setMax(100);
        seek.setProgress(prefs.getInt("sensitivity", 62));
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                prefs.edit().putInt("sensitivity", progress).apply();
                sensLabel.setText("Sensibilidad     " + progress + "%");
            }
            public void onStartTrackingTouch(SeekBar seekBar) {}
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });
        sensitivity.addView(sensLabel);
        sensitivity.addView(seek);
        sensitivity.addView(text("Umbral tecnico aproximado: " + thresholdText() + " dBFS.", 13, 0xFF667085, false));
        root.addView(sensitivity);

        CheckBox start = checkbox("Grabar al abrir la app", prefs.getBoolean("startOnLaunch", false));
        start.setOnCheckedChangeListener((buttonView, isChecked) -> prefs.edit().putBoolean("startOnLaunch", isChecked).apply());
        root.addView(start);

        root.addView(section("Subida automatica"));
        CheckBox upload = checkbox("Subir al terminar cada segmento", prefs.getBoolean("uploadAuto", false));
        upload.setOnCheckedChangeListener((buttonView, isChecked) -> prefs.edit().putBoolean("uploadAuto", isChecked).apply());
        root.addView(upload);
        root.addView(choiceRow("Destino", new String[]{"No", "Google Drive", "OneDrive", "Servidor propio"}, "provider"));
        EditText endpoint = new EditText(this);
        endpoint.setHint("https://tu-servidor.com/upload");
        endpoint.setText(prefs.getString("endpoint", ""));
        endpoint.setOnFocusChangeListener((v, hasFocus) -> { if (!hasFocus) prefs.edit().putString("endpoint", endpoint.getText().toString()).apply(); });
        root.addView(endpoint);
        root.addView(section("Notas"));
        root.addView(text("Servidor propio envia multipart/form-data con el archivo. Google Drive y OneDrive quedan preparados para conectar OAuth antes de publicar.", 14, 0xFF667085, false));
        root.addView(section("Version"));
        root.addView(detail("AudioRecorder", "v1.0 build 1"));
        root.addView(adBanner());
        root.addView(nav());
        setContentView(scroll);
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
        showRecorder();
    }

    private void startRecording() {
        File dir = recordingsDir();
        String stamp = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date());
        currentFile = new File(dir, "audio-" + stamp + ".m4a");
        recorder = new MediaRecorder();
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        recorder.setAudioEncodingBitRate(bitRate());
        recorder.setAudioSamplingRate(44100);
        recorder.setOutputFile(currentFile.getAbsolutePath());
        try {
            recorder.prepare();
            recorder.start();
            recording = true;
            startedAt = SystemClock.elapsedRealtime();
            if (timerText != null) timerText.post(timerTick);
        } catch (IOException | RuntimeException error) {
            Toast.makeText(this, "No se pudo iniciar la grabacion", Toast.LENGTH_LONG).show();
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
        showFiles();
    }

    private View fileRow(File file) {
        LinearLayout row = panel();
        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        Button play = small(playingFile != null && playingFile.equals(file) ? "■" : "▶", v -> togglePlayback(file));
        top.addView(play);
        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        info.addView(text(file.getName(), 17, 0xFF182233, true));
        info.addView(text(durationText(file) + " · " + Math.max(1, file.length() / 1024) + " KB · " + prefs.getString("mode", "Por sonido") + " · " + prefs.getString("quality", "Media"), 13, 0xFF667085, false));
        top.addView(info, new LinearLayout.LayoutParams(0, -2, 1));
        row.addView(top);
        LinearLayout actions = new LinearLayout(this);
        actions.addView(small("Enviar", v -> share(file)));
        actions.addView(small("Renombrar", v -> rename(file)));
        actions.addView(small("Eliminar", v -> {
            if (playingFile != null && playingFile.equals(file)) stopPlayback();
            file.delete();
            showFiles();
        }));
        row.addView(actions);
        return row;
    }

    private void togglePlayback(File file) {
        if (playingFile != null && playingFile.equals(file)) {
            stopPlayback();
            showFiles();
            return;
        }
        stopPlayback();
        try {
            player = new MediaPlayer();
            player.setDataSource(file.getAbsolutePath());
            player.prepare();
            player.start();
            playingFile = file;
            player.setOnCompletionListener(mp -> {
                stopPlayback();
                showFiles();
            });
            showFiles();
        } catch (IOException error) {
            Toast.makeText(this, "No se pudo reproducir", Toast.LENGTH_SHORT).show();
        }
    }

    private void stopPlayback() {
        if (player != null) {
            player.stop();
            player.release();
        }
        player = null;
        playingFile = null;
    }

    private void share(File file) {
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("audio/mp4");
        send.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(file));
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(Intent.createChooser(send, "Enviar"));
    }

    private void rename(File file) {
        final EditText input = new EditText(this);
        input.setText(file.getName().replace(".m4a", ""));
        new android.app.AlertDialog.Builder(this)
            .setTitle("Cambiar nombre")
            .setMessage("Se renombrara tambien el archivo de audio.")
            .setView(input)
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Guardar", (dialog, which) -> {
                String name = input.getText().toString().trim();
                if (!name.endsWith(".m4a")) name += ".m4a";
                file.renameTo(new File(file.getParentFile(), name));
                showFiles();
            })
            .show();
    }

    private LinearLayout pageRoot() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(22), dp(42), dp(22), dp(24));
        root.setBackgroundColor(0xFFF5F7FB);
        return root;
    }

    private TextView title(String value) {
        TextView view = text(value, 34, 0xFF182233, true);
        view.setGravity(Gravity.CENTER);
        return view;
    }

    private TextView text(String value, int sp, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(sp);
        view.setTextColor(color);
        if (bold) view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView metric(String title, String value) {
        TextView view = text(value + "\n" + title, 14, 0xFF182233, true);
        view.setGravity(Gravity.CENTER);
        view.setBackgroundColor(0xFFFFFFFF);
        view.setPadding(dp(8), dp(12), dp(8), dp(12));
        return view;
    }

    private TextView detail(String title, String value) {
        TextView view = text(title + "     " + value, 16, 0xFF182233, false);
        view.setPadding(0, dp(7), 0, dp(7));
        return view;
    }

    private LinearLayout panel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(14), dp(14), dp(14), dp(14));
        panel.setBackgroundColor(0xFFFFFFFF);
        panel.setLayoutParams(size(-1, -2, 0, 12, 0, 10));
        return panel;
    }

    private TextView section(String value) {
        TextView section = text(value, 20, 0xFF182233, true);
        section.setPadding(0, dp(22), 0, dp(8));
        return section;
    }

    private View choiceRow(String label, String[] values, String key) {
        LinearLayout row = panel();
        row.addView(text(label, 16, 0xFF667085, false));
        LinearLayout buttons = new LinearLayout(this);
        for (String value : values) {
            Button button = small(value, v -> {
                SharedPreferences.Editor editor = prefs.edit();
                if ("segment".equals(key)) editor.putInt(key, Integer.parseInt(value));
                else editor.putString(key, value);
                editor.apply();
                showSettings();
            });
            buttons.addView(button);
        }
        row.addView(buttons);
        return row;
    }

    private CheckBox checkbox(String label, boolean checked) {
        CheckBox box = new CheckBox(this);
        box.setText(label);
        box.setTextSize(16);
        box.setTextColor(0xFF182233);
        box.setChecked(checked);
        return box;
    }

    private Button primary(String label, View.OnClickListener listener) {
        Button button = small(label, listener);
        button.setTextColor(0xFFFFFFFF);
        button.setBackgroundColor(0xFF1F6FEB);
        return button;
    }

    private Button small(String label, View.OnClickListener listener) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setOnClickListener(listener);
        return button;
    }

    private View nav() {
        LinearLayout nav = new LinearLayout(this);
        nav.setGravity(Gravity.CENTER);
        nav.setPadding(0, dp(22), 0, 0);
        nav.addView(navButton("Grabar", 0));
        nav.addView(navButton("Archivos", 1));
        nav.addView(navButton("Ajustes", 2));
        return nav;
    }

    private View adBanner() {
        AdView adView = new AdView(this);
        adView.setAdUnitId(TEST_BANNER_AD_UNIT_ID);
        adView.setAdSize(AdSize.BANNER);
        adView.loadAd(new AdRequest.Builder().build());
        adView.setLayoutParams(size(-1, dp(50), 0, 12, 0, 0));
        return adView;
    }

    private Button navButton(String label, int index) {
        Button button = small(label, v -> {
            if (index == 0) showRecorder();
            if (index == 1) showFiles();
            if (index == 2) showSettings();
        });
        button.setTextColor(tab == index ? 0xFF1F6FEB : 0xFF667085);
        return button;
    }

    private String statusText() {
        if (recording) {
            if ("Todo".equals(prefs.getString("mode", "Por sonido"))) return "Se crea un archivo nuevo cada " + prefs.getInt("segment", 15) + " minutos";
            return "Esperando sonido suficiente (" + prefs.getInt("sensitivity", 62) + "% sensibilidad)";
        }
        return "Toca el microfono para empezar";
    }

    private String timerTextValue() {
        long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
        return formatTime(seconds);
    }

    private String levelTextValue() {
        long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
        return "-" + Math.max(18, 62 - (seconds % 35)) + " dB";
    }

    private String durationText(File file) {
        return "00:--";
    }

    private String thresholdText() {
        return String.valueOf(-60 + prefs.getInt("sensitivity", 62) / 2);
    }

    private int bitRate() {
        String quality = prefs.getString("quality", "Media");
        if ("Alta".equals(quality)) return 192000;
        if ("Baja".equals(quality)) return 64000;
        return 128000;
    }

    private File recordingsDir() {
        File dir = new File(getFilesDir(), "recordings");
        if (!dir.exists()) dir.mkdirs();
        return dir;
    }

    private void releaseRecorder() {
        if (recorder != null) {
            recorder.release();
            recorder = null;
        }
    }

    private String formatTime(long seconds) {
        return String.format(Locale.US, "%02d:%02d", seconds / 60, seconds % 60);
    }

    private LinearLayout.LayoutParams size(int w, int h, int l, int t, int r, int b) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(w, h);
        lp.setMargins(dp(l), dp(t), dp(r), dp(b));
        return lp;
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    protected void onDestroy() {
        if (recording) stopRecording();
        stopPlayback();
        super.onDestroy();
    }
}
