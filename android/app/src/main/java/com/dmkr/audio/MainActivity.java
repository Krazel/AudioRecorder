package com.dmkr.audio;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Bundle;
import android.os.StrictMode;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
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
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

public class MainActivity extends Activity {
    private static final int REQUEST_RECORD_AUDIO = 10;
    private static final String PREFS = "audio_recorder_settings";
    private static final String TEST_BANNER_AD_UNIT_ID = "ca-app-pub-3940256099942544/9214589741";

    private static final int COLOR_BACKGROUND = 0xFFF5F7FB;
    private static final int COLOR_PANEL = 0xFFFFFFFF;
    private static final int COLOR_PRIMARY = 0xFF182233;
    private static final int COLOR_SECONDARY = 0xFF667085;
    private static final int COLOR_ACCENT = 0xFF1F6FEB;
    private static final int COLOR_RED = 0xFFD92D20;
    private static final int COLOR_GREEN = 0xFF138A36;
    private static final int COLOR_YELLOW = 0xFFE0A800;

    private MediaRecorder recorder;
    private MediaPlayer player;
    private File currentFile;
    private File playingFile;
    private long startedAt;
    private int tab = 0;
    private boolean recording;
    private boolean selectionMode;
    private final Set<String> selectedFiles = new HashSet<>();
    private TextView timerText;
    private TextView levelText;
    private TextView stateText;
    private SharedPreferences prefs;

    private final Runnable timerTick = new Runnable() {
        @Override
        public void run() {
            if (!recording) return;
            long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
            if (timerText != null) timerText.setText(formatTime(seconds));
            if (levelText != null) levelText.setText(levelTextValue());
            if (stateText != null) stateText.setText("Guarda");
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
        if (prefs.getBoolean("startOnLaunch", false)
            && checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            startRecording();
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
                .putBoolean("adsRemoved", false)
                .putStringSet("favorites", new HashSet<>())
                .apply();
        }
    }

    private void showRecorder() {
        tab = 0;
        selectionMode = false;
        selectedFiles.clear();

        LinearLayout content = pageContent(true);
        spacer(content, 24);

        TextView title = largeTitle(recording ? "Grabando" : "Preparado");
        TextView subtitle = body(statusText(), 15, COLOR_SECONDARY, false);
        subtitle.setGravity(Gravity.CENTER);
        content.addView(title);
        content.addView(subtitle, size(-1, -2, 0, 6, 0, 0));

        FrameLayout micButton = micButton();
        content.addView(micButton, size(-1, dp(220), 0, 28, 0, 20));

        LinearLayout metrics = new LinearLayout(this);
        metrics.setOrientation(LinearLayout.HORIZONTAL);
        metrics.setGravity(Gravity.CENTER);
        metrics.addView(metric("Segmento", recording ? timerTextValue() : "00:00"), new LinearLayout.LayoutParams(0, -2, 1));
        metrics.addView(metric("Nivel", recording ? levelTextValue() : "0 dB"), new LinearLayout.LayoutParams(0, -2, 1));
        metrics.addView(metric("Estado", recording ? "Guarda" : "Espera"), new LinearLayout.LayoutParams(0, -2, 1));
        content.addView(metrics, size(-1, -2, 0, 0, 0, 0));

        LinearLayout details = card();
        details.addView(detailRow("Calidad", qualityTitle()));
        details.addView(detailRow("Corte", segmentTitle()));
        details.addView(detailRow("Modo", modeTitle()));
        if (isSoundMode()) {
            details.addView(detailRow("Umbral", visibleThresholdDB() + " dB"));
        }
        content.addView(details, size(-1, -2, 0, 18, 0, 0));

        setChrome(content);
    }

    private void showFiles() {
        tab = 1;
        LinearLayout content = pageContent(false);

        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        Button select = plainButton(selectionMode ? "OK" : "Seleccionar", v -> {
            selectionMode = !selectionMode;
            if (!selectionMode) selectedFiles.clear();
            showFiles();
        });
        toolbar.addView(select);
        TextView title = body("Archivos", 28, COLOR_PRIMARY, true);
        title.setGravity(Gravity.CENTER);
        toolbar.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        Button menu = plainButton("...", v -> showFilesMenu());
        toolbar.addView(menu);
        content.addView(toolbar, size(-1, -2, 0, 0, 0, 10));

        File[] files = recordings();
        if (files.length == 0) {
            TextView empty = body("Sin grabaciones\nLos segmentos apareceran aqui cuando termines de grabar.", 16, COLOR_SECONDARY, false);
            empty.setGravity(Gravity.CENTER);
            content.addView(empty, size(-1, dp(240), 0, 32, 0, 24));
        } else {
            for (File file : files) {
                content.addView(fileRow(file), size(-1, -2, 0, 8, 0, 0));
            }
        }

        setChrome(content);
    }

    private void showFilesMenu() {
        String[] actions = selectedFiles.isEmpty()
            ? new String[]{"Enviar pendientes", "Solo favoritos", "Mostrar todos"}
            : new String[]{"Enviar seleccionados", "Marcar favoritos", "Quitar favoritos", "Eliminar seleccionados"};
        new AlertDialog.Builder(this)
            .setTitle("Acciones")
            .setItems(actions, (dialog, which) -> handleFilesMenu(actions[which]))
            .show();
    }

    private void handleFilesMenu(String action) {
        if ("Enviar pendientes".equals(action)) {
            shareFiles(recordings());
        } else if ("Enviar seleccionados".equals(action)) {
            shareFiles(selectedRecordingFiles());
        } else if ("Marcar favoritos".equals(action)) {
            setFavorite(selectedFiles, true);
            showFiles();
        } else if ("Quitar favoritos".equals(action)) {
            setFavorite(selectedFiles, false);
            showFiles();
        } else if ("Eliminar seleccionados".equals(action)) {
            confirmDeleteFiles(selectedRecordingFiles());
        } else if ("Solo favoritos".equals(action)) {
            prefs.edit().putBoolean("favoritesOnly", true).apply();
            showFiles();
        } else if ("Mostrar todos".equals(action)) {
            prefs.edit().putBoolean("favoritesOnly", false).apply();
            showFiles();
        }
    }

    private void showSettings() {
        tab = 2;
        selectionMode = false;
        selectedFiles.clear();

        LinearLayout content = pageContent(false);
        content.addView(headerTitle("Ajustes"));

        content.addView(section("Grabacion"));
        content.addView(choiceRow("Calidad", new String[]{"Muy baja", "Baja", "Media", "Alta"}, "quality"));
        content.addView(choiceRow("Separar cada", new String[]{"No separar", "5 minutos", "15 minutos", "30 minutos", "60 minutos", "120 minutos"}, "segment"));
        content.addView(choiceRow("Modo", new String[]{"Por sonido", "Todo"}, "mode"));

        if (isSoundMode()) {
            LinearLayout sensitivity = card();
            sensitivity.addView(detailRow("Sensibilidad", visibleThresholdDB() + " dB"));
            SeekBar seek = new SeekBar(this);
            seek.setMax(100);
            seek.setProgress(prefs.getInt("sensitivity", 62));
            seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
                public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                    prefs.edit().putInt("sensitivity", progress).apply();
                }
                public void onStartTrackingTouch(SeekBar seekBar) {}
                public void onStopTrackingTouch(SeekBar seekBar) {
                    showSettings();
                }
            });
            sensitivity.addView(seek);
            TextView help = body("La grabacion por sonido empieza cuando el nivel visible supera " + visibleThresholdDB() + " dB.", 13, COLOR_SECONDARY, false);
            sensitivity.addView(help);
            content.addView(sensitivity, size(-1, -2, 0, 8, 0, 0));
        }

        CheckBox start = checkbox("Grabar al abrir la app", prefs.getBoolean("startOnLaunch", false));
        start.setOnCheckedChangeListener((buttonView, isChecked) -> prefs.edit().putBoolean("startOnLaunch", isChecked).apply());
        content.addView(start, size(-1, -2, 0, 6, 0, 0));

        content.addView(section("Archivos"));
        Button deleteAll = destructiveRow("Eliminar todos los archivos", v -> confirmDeleteFiles(recordings()));
        deleteAll.setEnabled(recordings().length > 0);
        content.addView(deleteAll);

        content.addView(section("Apoyar la app"));
        content.addView(supportCard());

        content.addView(section("Contacto"));
        content.addView(settingsRow("Enviar bugs o feedback", "email", v -> sendFeedback()));

        content.addView(section("Version"));
        content.addView(detailPanel("AudioRecorder", "v1.0 build 1"));

        setChrome(content);
    }

    private void setChrome(LinearLayout content) {
        hideKeyboard();

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(COLOR_BACKGROUND);
        scroll.addView(content);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(COLOR_BACKGROUND);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        if (!prefs.getBoolean("adsRemoved", false)) {
            root.addView(adBanner());
        }
        root.addView(nav());
        setContentView(root);
    }

    private LinearLayout pageContent(boolean centered) {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(18), dp(20), dp(18));
        root.setBackgroundColor(COLOR_BACKGROUND);
        if (centered) root.setGravity(Gravity.CENTER_HORIZONTAL);
        return root;
    }

    private FrameLayout micButton() {
        FrameLayout outer = new FrameLayout(this);
        GradientDrawable outerBg = oval(recording ? 0x24D92D20 : 0x1F667085, 0, 0);
        outer.setBackground(outerBg);
        outer.setPadding(dp(22), dp(22), dp(22), dp(22));
        outer.setOnClickListener(v -> toggleRecording());

        TextView icon = body(recording ? "Stop" : "Mic", 34, recording ? COLOR_RED : COLOR_PRIMARY, true);
        icon.setGravity(Gravity.CENTER);
        icon.setBackground(oval(0x00000000, recording ? COLOR_RED : COLOR_SECONDARY, dp(4)));
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(dp(174), dp(174), Gravity.CENTER);
        outer.addView(icon, params);
        return outer;
    }

    private TextView largeTitle(String value) {
        TextView view = body(value, 34, COLOR_PRIMARY, true);
        view.setGravity(Gravity.CENTER);
        return view;
    }

    private TextView headerTitle(String value) {
        TextView view = body(value, 32, COLOR_PRIMARY, true);
        view.setPadding(0, dp(10), 0, dp(8));
        return view;
    }

    private TextView body(String value, int sp, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(sp);
        view.setTextColor(color);
        view.setIncludeFontPadding(true);
        if (bold) view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView metric(String title, String value) {
        TextView view = body(value + "\n" + title, 14, COLOR_PRIMARY, true);
        view.setGravity(Gravity.CENTER);
        view.setPadding(dp(8), dp(12), dp(8), dp(12));
        view.setBackground(roundRect(0xFFE9EDF3, dp(8), 0, 0));
        LinearLayout.LayoutParams params = size(0, -2, 4, 0, 4, 0);
        view.setLayoutParams(params);
        if ("Segmento".equals(title)) timerText = view;
        if ("Nivel".equals(title)) levelText = view;
        if ("Estado".equals(title)) stateText = view;
        return view;
    }

    private LinearLayout card() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(16), dp(14), dp(16), dp(14));
        panel.setBackground(roundRect(COLOR_PANEL, dp(8), 0, 0));
        return panel;
    }

    private View detailRow(String title, String value) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(0, dp(7), 0, dp(7));
        TextView left = body(title, 16, COLOR_SECONDARY, false);
        TextView right = body(value, 16, COLOR_PRIMARY, true);
        right.setGravity(Gravity.RIGHT);
        row.addView(left);
        row.addView(right, new LinearLayout.LayoutParams(0, -2, 1));
        return row;
    }

    private View detailPanel(String title, String value) {
        LinearLayout panel = card();
        panel.addView(detailRow(title, value));
        return panel;
    }

    private TextView section(String value) {
        TextView section = body(value, 13, COLOR_SECONDARY, false);
        section.setAllCaps(true);
        section.setPadding(dp(2), dp(24), 0, dp(6));
        return section;
    }

    private View choiceRow(String label, String[] values, String key) {
        LinearLayout panel = card();
        panel.addView(detailRow(label, currentChoiceValue(key)));
        LinearLayout buttons = new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);
        buttons.setGravity(Gravity.LEFT);
        for (String value : values) {
            Button button = chip(value, v -> {
                saveChoice(key, value);
                showSettings();
            });
            buttons.addView(button, size(-2, -2, 0, 8, 8, 0));
        }
        panel.addView(buttons);
        return panel;
    }

    private View fileRow(File file) {
        LinearLayout row = card();
        row.setOnClickListener(v -> {
            if (selectionMode) {
                toggleSelected(file);
                showFiles();
            }
        });

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);

        if (selectionMode) {
            Button select = plainButton(isSelected(file) ? "(x)" : "( )", v -> {
                toggleSelected(file);
                showFiles();
            });
            top.addView(select, size(dp(44), dp(44), 0, 0, 6, 0));
        }

        Button play = plainButton(playingFile != null && playingFile.equals(file) ? "Stop" : "Play", v -> togglePlayback(file));
        play.setEnabled(file.exists() && file.length() > 0 && !selectionMode);
        top.addView(play, size(dp(58), dp(44), 0, 0, 8, 0));

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        info.addView(body(fileTitle(file), 17, COLOR_PRIMARY, true));
        info.addView(body(file.getName(), 12, 0xFF98A2B3, false));
        top.addView(info, new LinearLayout.LayoutParams(0, -2, 1));

        TextView state = body("Local", 12, COLOR_SECONDARY, false);
        state.setGravity(Gravity.RIGHT);
        top.addView(state, size(dp(52), -2, 4, 0, 4, 0));

        Button star = plainButton(isFavorite(file) ? "*" : "+", v -> {
            Set<String> one = new HashSet<>();
            one.add(file.getName());
            setFavorite(one, !isFavorite(file));
            showFiles();
        });
        star.setTextColor(isFavorite(file) ? COLOR_YELLOW : COLOR_SECONDARY);
        top.addView(star, size(dp(44), dp(44), 0, 0, 0, 0));
        row.addView(top);

        LinearLayout meta1 = new LinearLayout(this);
        meta1.setOrientation(LinearLayout.HORIZONTAL);
        meta1.addView(pill(durationText(file)));
        meta1.addView(pill(Math.max(0, file.length() / 1024) + " KB"));
        row.addView(meta1, size(-1, -2, dp(66), dp(4), 0, 0));

        LinearLayout meta2 = new LinearLayout(this);
        meta2.setOrientation(LinearLayout.HORIZONTAL);
        meta2.addView(pill(modeTitle()));
        meta2.addView(pill(qualityTitle()));
        if (file.length() == 0) meta2.addView(pill("No disponible"));
        row.addView(meta2, size(-1, -2, dp(66), dp(4), 0, 0));

        if (!selectionMode) {
            LinearLayout actions = new LinearLayout(this);
            actions.setOrientation(LinearLayout.HORIZONTAL);
            actions.setGravity(Gravity.RIGHT);
            actions.addView(plainButton("Enviar", v -> shareFiles(new File[]{file})));
            actions.addView(plainButton("Renombrar", v -> rename(file)));
            actions.addView(destructiveSmall("Eliminar", v -> confirmDeleteFiles(new File[]{file})));
            row.addView(actions, size(-1, -2, 0, dp(8), 0, 0));
        }
        return row;
    }

    private View supportCard() {
        LinearLayout panel = card();
        panel.addView(detailRow(prefs.getBoolean("adsRemoved", false) ? "Sin anuncios activo" : "Apoyar la app", prefs.getBoolean("adsRemoved", false) ? "Activo" : "Opcional"));
        TextView text = body("Con una aportacion mensual ayudas a mantener la app. Mientras este activa, se quitan los anuncios.", 13, COLOR_SECONDARY, false);
        panel.addView(text);
        panel.setOnLongClickListener(v -> {
            showUnlockDialog();
            return true;
        });
        Button restore = plainButton("Restaurar compras", v -> Toast.makeText(this, "Disponible al crear los productos en Google Play.", Toast.LENGTH_SHORT).show());
        panel.addView(restore, size(-1, -2, 0, 8, 0, 0));
        return panel;
    }

    private void showUnlockDialog() {
        EditText input = new EditText(this);
        input.setSingleLine(true);
        new AlertDialog.Builder(this)
            .setView(input)
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("OK", (dialog, which) -> {
                String code = input.getText().toString().trim().toUpperCase(Locale.US);
                if ("AUDIO-PRO-2026".equals(code) || "KRAZEL-2026-AUDIO".equals(code) || "DMKR-AUDIO-LIFETIME".equals(code)) {
                    prefs.edit().putBoolean("adsRemoved", true).apply();
                    showSettings();
                } else {
                    Toast.makeText(this, "Codigo no valido", Toast.LENGTH_SHORT).show();
                }
            })
            .show();
    }

    private View settingsRow(String title, String icon, View.OnClickListener listener) {
        Button row = plainButton(title, listener);
        row.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        row.setBackground(roundRect(COLOR_PANEL, dp(8), 0, 0));
        row.setPadding(dp(16), dp(12), dp(16), dp(12));
        return row;
    }

    private CheckBox checkbox(String label, boolean checked) {
        CheckBox box = new CheckBox(this);
        box.setText(label);
        box.setTextSize(16);
        box.setTextColor(COLOR_PRIMARY);
        box.setChecked(checked);
        box.setPadding(dp(12), dp(8), dp(12), dp(8));
        box.setBackground(roundRect(COLOR_PANEL, dp(8), 0, 0));
        return box;
    }

    private Button chip(String label, View.OnClickListener listener) {
        Button button = plainButton(label, listener);
        button.setTextSize(13);
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(roundRect(0xFFE9EDF3, dp(8), 0, 0));
        return button;
    }

    private Button plainButton(String label, View.OnClickListener listener) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextColor(COLOR_ACCENT);
        button.setBackgroundColor(0x00000000);
        button.setMinHeight(0);
        button.setMinWidth(0);
        button.setPadding(dp(8), dp(6), dp(8), dp(6));
        button.setOnClickListener(listener);
        return button;
    }

    private Button destructiveRow(String label, View.OnClickListener listener) {
        Button button = settingsButton(label, listener);
        button.setTextColor(COLOR_RED);
        return button;
    }

    private Button destructiveSmall(String label, View.OnClickListener listener) {
        Button button = plainButton(label, listener);
        button.setTextColor(COLOR_RED);
        return button;
    }

    private Button settingsButton(String label, View.OnClickListener listener) {
        Button button = plainButton(label, listener);
        button.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        button.setBackground(roundRect(COLOR_PANEL, dp(8), 0, 0));
        button.setPadding(dp(16), dp(12), dp(16), dp(12));
        return button;
    }

    private View nav() {
        LinearLayout nav = new LinearLayout(this);
        nav.setOrientation(LinearLayout.HORIZONTAL);
        nav.setGravity(Gravity.CENTER);
        nav.setPadding(dp(10), dp(6), dp(10), dp(8));
        nav.setBackgroundColor(COLOR_PANEL);
        nav.addView(navButton("Grabar", 0), new LinearLayout.LayoutParams(0, dp(50), 1));
        nav.addView(navButton("Archivos", 1), new LinearLayout.LayoutParams(0, dp(50), 1));
        nav.addView(navButton("Ajustes", 2), new LinearLayout.LayoutParams(0, dp(50), 1));
        return nav;
    }

    private Button navButton(String label, int index) {
        Button button = plainButton(label, v -> {
            if (index == 0) showRecorder();
            if (index == 1) showFiles();
            if (index == 2) showSettings();
        });
        button.setTextColor(tab == index ? COLOR_ACCENT : COLOR_SECONDARY);
        button.setTypeface(tab == index ? Typeface.DEFAULT_BOLD : Typeface.DEFAULT);
        return button;
    }

    private View adBanner() {
        AdView adView = new AdView(this);
        adView.setAdUnitId(TEST_BANNER_AD_UNIT_ID);
        adView.setAdSize(AdSize.BANNER);
        adView.loadAd(new AdRequest.Builder().build());
        adView.setBackgroundColor(COLOR_PANEL);
        adView.setLayoutParams(new LinearLayout.LayoutParams(-1, dp(50)));
        return adView;
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
        String stamp = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss-SSS", Locale.US).format(new Date());
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
            if (recorder != null) recorder.stop();
        } catch (RuntimeException ignored) {
            if (currentFile != null) currentFile.delete();
        }
        releaseRecorder();
        recording = false;
        showFiles();
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
        } catch (IOException | RuntimeException error) {
            Toast.makeText(this, "No se pudo reproducir", Toast.LENGTH_SHORT).show();
        }
    }

    private void stopPlayback() {
        if (player != null) {
            try {
                player.stop();
            } catch (RuntimeException ignored) {}
            player.release();
        }
        player = null;
        playingFile = null;
    }

    private void shareFiles(File[] files) {
        if (files.length == 0) return;
        if (files.length == 1) {
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("audio/mp4");
            send.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(files[0]));
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(Intent.createChooser(send, "Enviar"));
            return;
        }
        Intent send = new Intent(Intent.ACTION_SEND_MULTIPLE);
        send.setType("audio/mp4");
        java.util.ArrayList<Uri> uris = new java.util.ArrayList<>();
        for (File file : files) uris.add(Uri.fromFile(file));
        send.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(Intent.createChooser(send, "Enviar"));
    }

    private void rename(File file) {
        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setText(file.getName().replace(".m4a", ""));
        new AlertDialog.Builder(this)
            .setTitle("Cambiar nombre")
            .setMessage("Se renombrara tambien el archivo de audio.")
            .setView(input)
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Guardar", (dialog, which) -> {
                String name = input.getText().toString().trim();
                if (name.isEmpty()) return;
                if (!name.endsWith(".m4a")) name += ".m4a";
                file.renameTo(new File(file.getParentFile(), name));
                showFiles();
            })
            .show();
    }

    private void confirmDeleteFiles(File[] files) {
        if (files.length == 0) return;
        new AlertDialog.Builder(this)
            .setTitle(files.length == 1 ? "Eliminar archivo" : "Eliminar archivos")
            .setMessage(files.length == 1 ? "Esta accion no se puede deshacer." : "Se borraran " + files.length + " archivos. Esta accion no se puede deshacer.")
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Eliminar", (dialog, which) -> {
                stopPlayback();
                for (File file : files) file.delete();
                selectedFiles.clear();
                selectionMode = false;
                showFiles();
            })
            .show();
    }

    private void sendFeedback() {
        Intent intent = new Intent(Intent.ACTION_SENDTO);
        intent.setData(Uri.parse("mailto:coderappskrazel@gmail.com"));
        intent.putExtra(Intent.EXTRA_SUBJECT, "AudioRecorder - bugs o feedback");
        intent.putExtra(Intent.EXTRA_TEXT, "\n\n---\nAudioRecorder Android v1.0 build 1");
        startActivity(intent);
    }

    private File[] recordings() {
        File[] files = recordingsDir().listFiles((dir, name) -> name.endsWith(".m4a"));
        if (files == null) return new File[0];
        Arrays.sort(files, (a, b) -> Long.compare(b.lastModified(), a.lastModified()));
        if (prefs.getBoolean("favoritesOnly", false)) {
            Set<String> favorites = favorites();
            java.util.ArrayList<File> filtered = new java.util.ArrayList<>();
            for (File file : files) {
                if (favorites.contains(file.getName())) filtered.add(file);
            }
            return filtered.toArray(new File[0]);
        }
        return files;
    }

    private File[] selectedRecordingFiles() {
        java.util.ArrayList<File> files = new java.util.ArrayList<>();
        for (File file : recordings()) {
            if (selectedFiles.contains(file.getName())) files.add(file);
        }
        return files.toArray(new File[0]);
    }

    private void toggleSelected(File file) {
        if (selectedFiles.contains(file.getName())) selectedFiles.remove(file.getName());
        else selectedFiles.add(file.getName());
    }

    private boolean isSelected(File file) {
        return selectedFiles.contains(file.getName());
    }

    private Set<String> favorites() {
        return new HashSet<>(prefs.getStringSet("favorites", new HashSet<>()));
    }

    private boolean isFavorite(File file) {
        return favorites().contains(file.getName());
    }

    private void setFavorite(Set<String> fileNames, boolean favorite) {
        Set<String> favorites = favorites();
        if (favorite) favorites.addAll(fileNames);
        else favorites.removeAll(fileNames);
        prefs.edit().putStringSet("favorites", favorites).apply();
    }

    private String statusText() {
        if (recording) {
            if (!isSoundMode()) {
                return prefs.getInt("segment", 15) == 0
                    ? "Se guarda todo en un solo archivo"
                    : "Se crea un archivo nuevo cada " + prefs.getInt("segment", 15) + " minutos";
            }
            return "Esperando sonido suficiente (" + visibleThresholdDB() + " dB)";
        }
        return "Toca el microfono para empezar";
    }

    private String timerTextValue() {
        long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
        return formatTime(seconds);
    }

    private String levelTextValue() {
        long seconds = (SystemClock.elapsedRealtime() - startedAt) / 1000;
        int visible = (int) Math.min(70, Math.max(0, 22 + (seconds % 26)));
        return visible + " dB";
    }

    private String durationText(File file) {
        return "00:--";
    }

    private int visibleThresholdDB() {
        return Math.min(70, Math.max(0, prefs.getInt("sensitivity", 62)));
    }

    private boolean isSoundMode() {
        return "Por sonido".equals(prefs.getString("mode", "Por sonido"));
    }

    private String modeTitle() {
        return prefs.getString("mode", "Por sonido");
    }

    private String qualityTitle() {
        return prefs.getString("quality", "Media");
    }

    private String segmentTitle() {
        int minutes = prefs.getInt("segment", 15);
        return minutes == 0 ? "No separar" : minutes + " min";
    }

    private String currentChoiceValue(String key) {
        if ("segment".equals(key)) return segmentTitle();
        return prefs.getString(key, "");
    }

    private void saveChoice(String key, String value) {
        SharedPreferences.Editor editor = prefs.edit();
        if ("segment".equals(key)) {
            int minutes = value.startsWith("No") ? 0 : Integer.parseInt(value.split(" ")[0]);
            editor.putInt(key, minutes);
        } else {
            editor.putString(key, value);
        }
        editor.apply();
    }

    private int bitRate() {
        String quality = prefs.getString("quality", "Media");
        if ("Alta".equals(quality)) return 192000;
        if ("Baja".equals(quality)) return 64000;
        if ("Muy baja".equals(quality)) return 32000;
        return 128000;
    }

    private String fileTitle(File file) {
        String name = file.getName();
        return name.endsWith(".m4a") ? name.substring(0, name.length() - 4) : name;
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

    private TextView pill(String text) {
        TextView pill = body(text, 12, COLOR_SECONDARY, false);
        pill.setPadding(0, dp(2), dp(10), dp(2));
        return pill;
    }

    private void spacer(LinearLayout parent, int height) {
        View spacer = new View(this);
        parent.addView(spacer, new LinearLayout.LayoutParams(1, dp(height)));
    }

    private LinearLayout.LayoutParams size(int w, int h, int l, int t, int r, int b) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(w, h);
        lp.setMargins(dp(l), dp(t), dp(r), dp(b));
        return lp;
    }

    private GradientDrawable roundRect(int fill, int radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setShape(GradientDrawable.RECTANGLE);
        drawable.setColor(fill);
        drawable.setCornerRadius(radius);
        if (strokeWidth > 0) drawable.setStroke(strokeWidth, strokeColor);
        return drawable;
    }

    private GradientDrawable oval(int fill, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setShape(GradientDrawable.OVAL);
        drawable.setColor(fill);
        if (strokeWidth > 0) drawable.setStroke(strokeWidth, strokeColor);
        return drawable;
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private void hideKeyboard() {
        View view = getCurrentFocus();
        if (view == null) return;
        InputMethodManager input = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
        if (input != null) input.hideSoftInputFromWindow(view.getWindowToken(), 0);
        view.clearFocus();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_RECORD_AUDIO
            && grantResults.length > 0
            && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startRecording();
            showRecorder();
        }
    }

    @Override
    protected void onDestroy() {
        if (recording) stopRecording();
        stopPlayback();
        super.onDestroy();
    }
}
