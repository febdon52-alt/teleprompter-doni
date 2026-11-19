# Baca Kamera — teleprompter untuk kreator

Aplikasi web (PWA) untuk iPhone: cari ide konten, dapat naskah yang siap dibaca, lalu baca di teleprompter sambil merekam dengan kamera depan. Semua berjalan di satu file `index.html`, tanpa server dan tanpa build.

## Fitur

**Ide & naskah**
- 10 niche siap pakai (bisnis, keuangan, kuliner, produktivitas, teknologi, skincare, kesehatan, parenting, traveling, motivasi) plus topik bebas.
- Pilih platform (TikTok/Reels/Shorts atau YouTube panjang), durasi (15 detik sampai 8 menit), dan gaya bicara (santai, edukatif, storytelling, lucu, inspiratif, soft selling).
- 5 ide sekaligus dengan sudut berbeda: tips, kesalahan umum, cerita pribadi, satu hal penting, panduan pemula, opini tidak populer, tantangan 7 hari. Tiap ide sudah punya judul dan hook.
- Naskah lengkap dengan bagian `## HOOK`, `## ISI`, `## PENUTUP`, arahan dalam (kurung), dan CTA sesuai platform. Panjangnya menyesuaikan durasi (±150 kata per menit).
- Tiga mesin:
  - **Bawaan**: bank ide dan naskah di dalam aplikasi. Gratis, tanpa internet.
  - **Claude API**: isi API key Anthropic di tab Atur (Opus 5.5, Sonnet 5.5, atau Haiku 5.5). Kunci hanya disimpan di iPhone Anda.
  - **Claude**: saat dibuka sebagai artifact di claude.ai, ide dan naskah ditulis memakai akun Claude Anda tanpa API key.

**Teleprompter**
- Gulir halus dengan kecepatan dan ukuran huruf yang bisa diatur saat membaca.
- Garis baca di sepertiga atas layar, dekat kamera depan dan Dynamic Island iPhone 15, supaya mata tetap terlihat menatap kamera.
- Hitung mundur, mode cermin untuk kaca teleprompter, rata tengah, sisa waktu baca.
- Ketuk layar untuk jeda/lanjut, geser untuk menggulir manual.
- Remote Bluetooth/keyboard: Spasi = putar/jeda, ↑/↓ = kecepatan, PageUp/PageDown = lompat, Esc = tutup.
- Layar tidak meredup selama membaca (Screen Wake Lock).
- **Rekam**: kamera depan tampil di belakang teks, rekam video + suara (hingga 1080p), lalu simpan ke app Foto lewat menu Bagikan.
- **Rasio**: 9:16 (TikTok/Reels/Shorts), 3:4 (bidang pandang penuh sensor, paling lebar), 4:5 (Instagram feed), 1:1, dan 16:9 (YouTube). Kualitas 1080p atau 720p. Ukuran video hasil sama persis dengan yang tertulis di layar.
- **Zoom manual**: slider, tombol − / +, tombol 1×, atau cubit layar dengan dua jari. Rentang 0,6× sampai 3×; di bawah 1× gambar mengecil dan tepinya diisi buram. Zoom bisa diubah saat merekam. Pratinjau persis sama dengan hasil rekaman karena gambar disusun lewat kanvas (zoom hardware kamera depan iPhone tidak tersedia untuk web).
- **Rekaman aman**: setiap rekaman langsung disimpan di aplikasi (dibaca ulang untuk memastikan), bisa dibuka lagi dari Atur › Rekaman tersimpan, lalu disimpan ke Foto atau diunduh. Bila kamera terputus di tengah rekaman, bagian yang sudah terekam tetap diselamatkan.
- **Bila rekam bermasalah**: muncul pesan dengan rincian teknis dan tombol **Rekam dengan kamera iPhone** (kamera bawaan, hasilnya masuk ke aplikasi). Atur › **Uji kamera & rekam** menjalankan diagnosis 3 detik.

Naskah tersimpan otomatis di perangkat (localStorage).

## Memasang di iPhone

Alamat aplikasi: **https://febdon52-alt.github.io/teleprompter-doni/**

Buka di **Safari** iPhone › **Bagikan** › **Tambahkan ke Layar Utama** › **Tambah**. Buka dari ikon di Layar Utama, lalu izinkan kamera dan mikrofon saat pertama kali merekam.

Situs diterbitkan otomatis oleh `.github/workflows/pages.yml` setiap ada perubahan di `main`. Di Settings › Pages, atur Source ke **GitHub Actions** satu kali.

## Mencoba di komputer

```bash
python3 -m http.server 8080
```

Lalu buka http://localhost:8080.

## Berkas

| Berkas | Isi |
|---|---|
| `index.html` | Seluruh aplikasi: tampilan, bank ide, penulis naskah, teleprompter, perekam |
| `manifest.webmanifest` | Nama, ikon, dan mode layar penuh untuk Layar Utama |
| `sw.js` | Service worker supaya bisa dibuka tanpa internet |
| `icons/` | Ikon aplikasi |
