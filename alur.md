### Alur Aplikasi Pomodoro Focus

### 1\. Alur Inisialisasi Aplikasi

1\. Inisialisasi Mesin Flutter (`WidgetsFlutterBinding.ensureInitialized()`)

* Memastikan jembatan sistem OS HP dan Flutter siap sebelum proses asinkron berjalan.

2\. Inisialisasi Firebase (`await Firebase.initializeApp()`)

* Menghubungkan aplikasi ke layanan Firebase Auth dan Cloud Firestore.

3\. Mendaftarkan Service via MultiProvider

* Menyediakan `AuthService`, `SessionRepository`, dan `MediaService`.

* Memakai `ProxyProvider` untuk mencolokkan `MediaService` ke dalam `TimerService` (agar bisa bunyikan alarm).

* Sekaligus langsung mengeksekusi `initialize()` pada `TimerService` (meminta izin notifikasi HP & memulihkan sesi aktif terakhir dari memori lokal).

4\. Konfigurasi Tema Gelap (`theme: AppTheme.darkTheme`)

* Mengatur pewarnaan UI terpusat agar konsisten di seluruh layar.

5\. Menjalankan AuthGate (`home: const AuthGate()`)

* Gerbang penentu tampilan secara real-time: jika sudah login langsung merender `TimerScreen`, jika belum merender `LoginScreen`.

### 2\. Alur Autentikasi (Auth Flow)

1\. AuthGate Mengawasi Status Akun

* Mengambil `AuthService` dari Provider dan mendengarkan aliran data `authStateChanges` secara real-time.

2\. Pemeriksaan Kondisi Awal (`Snapshot`)

* `waiting`: Menampilkan indikator loading muter-muter.

* `null`: Pengguna belum login → `AuthGate` menampilkan `LoginScreen`.

3\. Proses Masuk (Login)

* a. Validasi Form & Input: Form dicek kelengkapannya menggunakan controller teks di `LoginScreen`.

* b. Kirim ke Service: Memanggil method `login()` pada `AuthService` dengan membawa email & password.

* c. Penerjemahan Data: Jika login sukses di Firebase, data mentah Firebase diterjemahkan menjadi objek bersih oleh `AppUser` (`AppUser.fromFirebaseUser`). Jika email/password salah, error langsung ditangkap dan muncul SnackBar merah.

* d. Tampilan Otomatis Berganti: Karena status user di Firebase sudah tidak `null`, `AuthGate` otomatis merender `TimerScreen` tanpa navigasi manual.

4\. Proses Daftar (Register)

* Membuka form registrasi (`Navigator.push`).

* Mengirim email & password baru ke `authService.register()` untuk membuat akun baru di Firebase Auth.

* Begitu berhasil, akun baru tersebut otomatis langsung dianggap login oleh Firebase, dan diarahkan ke `TimerScreen`.

5\. Lupa Password (Reset Password)

* Membuka dialog reset password, hanya memasukkan email.

* Memanggil `authService.resetPassword()` untuk meminta Firebase mengirimkan tautan reset kata sandi ke email pengguna.

### 3\. Alur Media (Audio Ambience & Video Background)

1\. Trigger Modal Pemilihan Media

* Tombol nada musik di AppBar `TimerScreen` membuka modal bawah (`MediaSelectorSheet`).

* Icon di AppBar otomatis menyesuaikan: tebal (solid) jika media aktif, atau garis tepi (outlined) jika belum ada yang dipilih.

2\. Pengambilan URL Media Terpusat

* URL audio (hujan dan lofi) serta video (kereta dan hutan) diambil dari konstanta terpusat di `AppConstants`.

3\. Pemilihan & Pemutaran Audio Ambience

* Saat salah satu tombol audio dipilih, dipanggil `mediaService.playAmbience(url)`.

* Di dalam service:

    * Cek apakah URL sama & sedang jalan (mencegah play ulang yang tidak perlu).

    * Simpan URL & jalankan `notifyListeners()` agar tombol di modal langsung berubah status jadi terpilih.

    * Pasang URL ke `_ambiencePlayer`, aktifkan perulangan tanpa henti (`LoopMode.one`), atur volume sesuai slider, lalu `play()`.

4\. Pengaturan Volume Real-time

* Slider volume di sheet memanggil `mediaService.setAmbienceVolume(val)` yang langsung mengubah level suara di pemutar audio fisik secara mulus.

5\. Pemilihan & Penayangan Video Background

* URL video dikirim ke `mediaService.setVideoBackground(url)`. Service menginisialisasi controller video, mengaktifkan loop, dan mematikan volume agar video berjalan bersama audio ambience.

* `TimerScreen` menampilkan `videoController` secara langsung pada lapisan terbawah `Stack` dengan `Positioned.fill` dan `FittedBox(fit: BoxFit.cover)`, lalu menambahkan lapisan hitam transparan 55% agar teks timer tetap mudah dibaca. Tidak ada widget `VideoTimerView` terpisah.

* Pilihan "Mati" memanggil `setVideoBackground(null)` untuk melepas video yang sedang aktif.

* Kontrol yang tersedia di `MediaSelectorSheet` adalah memilih atau menghentikan audio ambience, mengatur volumenya, serta memilih atau mematikan video latar. Tidak ada kontrol jeda/lanjut media.

### 4\. Alur Pemilihan Durasi

1\. Syarat Tampil (`if (isIdle)`)

* Pilihan durasi hanya muncul saat timer belum berjalan (status `idle`). Begitu tombol mulai ditekan, kontrol ini otomatis disembunyikan agar user tidak bisa mengubah waktu di tengah sesi.

2\. Dua Cara Memilih Durasi

* Opsi A: Tombol Preset Instan (`ChoiceChip`)

    * Looping daftar `[15, 30, 45, 60]`.

    * Saat user klik salah satu chip (misal `30m`), teks di controller diubah jadi `'30'` dan memanggil `timerService.setTotalMinutes(30)`.

\* Opsi B: Ketik Angka Bebas (`TextField Custom`)

* User bisa mengetik angka sendiri (misal: `20`, `90`).

* Dilindungi `FocusNode`: saat keyboard aktif mengetik, teks tidak akan tertimpa/terkunci oleh update state layar.

* Begitu diketik (`onChanged`) atau dienter (`onSubmitted`), asalkan angkanya ≥ 1, langsung memanggil `timerService.setTotalMinutes(...)`.

3\. Oper Data: Screen → Service → Engine

* `TimerScreen` mengirim angka menit ke `TimerService.setTotalMinutes(menit)`.

* `TimerService` mengoper angka tersebut ke `TimerEngine`.

4\. Engine Menghitung Siklus Pomodoro (`_generatePlans`)

* `TimerEngine` otomatis memecah total durasi menjadi rencana fase:

    * Contoh 30 menit: dipecah menjadi 25 menit Fokus + 5 menit Istirahat.

    * Contoh 15 menit: dipecah menjadi 15 menit Fokus murni.

5\. Simpan ke Memori Lokal & Update UI

* `TimerService` menyimpan rencana baru ke penyimpanan lokal HP (`SharedPreferences`).

* Memanggil `notifyListeners()`.

* Layar merespons: teks rincian di bawah berganti (misal: "1x Fokus (25m) + 1x Istirahat (5m)") dan lingkaran timer siap di angka fokus pertama.

### 5\. Alur Sesi Lengkap Pomodoro Focus (dengan Kondisi "What-If")

* `TimerEngine.tick()` memajukan fase berdasarkan waktu target `endAt`. Kondisi perulangannya memeriksa status timer dan memastikan `endAt` tidak null sebelum membandingkan waktu; saat fase terakhir selesai, timer berstatus `finished` tanpa membaca target yang sudah dikosongkan.

* Sesi 1 menit terdiri dari satu fase fokus 1 menit. Setelah targetnya tercapai, `tick()` mengembalikan `TimerStatus.finished` dan alur penyelesaian yang sama dijalankan.

### 5.1. Memulai Sesi (`timerService.start()`)

* User menekan tombol "Mulai \[N\] Menit".

* Engine mencatat jam mulai (`startAt`), target selesai (`endAt`), dan status jadi `running`.

* `WakelockPlus.enable()` aktif (layar HP tahan mati).

* Penjadwalan Alarm: Mendaftarkan seluruh alarm fase ke sistem OS Android/iOS via `AlarmManager`.

* State disimpan ke memori internal HP (`SharedPreferences`).

### 5.2. Skenario "What-If" Saat Sesi Berjalan

\* What-If 1: Layar Diminimize / Tombol Home / Layar HP Dimatikan

* Musik & Audio: Tetap berputar di background berkat `just_audio`.

* Timer: Sistem tetap melacak target waktu `endAt`.

* Notifikasi OS: Karena alarm sudah dijadwalkan ke level sistem OS di awal (`exactAllowWhileIdle`), saat waktu fase atau sesi habis, HP tetap berdering dan memunculkan banner notifikasi meskipun aplikasi sedang tertutup/tertidur (anti-Doze mode).

* Saat aplikasi dibuka lagi, `_restoreState()` menghitung selisih waktu sekarang dengan `endAt` sehingga angka timer langsung sinkron seketika.

\* What-If 2: Pengguna Menekan Tombol "Jeda" (Pause)

* Engine menghitung sisa waktu terakhir dan menyimpannya ke `_pausedRemaining`, lalu status jadi `paused`.

* Detak ticker dimatikan (`_stopTicker()`).

* `WakelockPlus.disable()` (layar HP dibolehkan mati saat jeda).

* Semua alarm notifikasi di OS ditarik/dibatalkan (`cancelAllNotifications`) agar alarm tidak salah berdering saat sesi lagi ditunda.

* Status disimpan ke `SharedPreferences` dan tombol di layar berubah menjadi "Lanjut" (Resume) dan "Reset".

* (Jika tombol "Lanjut" ditekan: target `endAt` baru dihitung ulang dari waktu sekarang + `_pausedRemaining`, dan alarm notifikasi didaftarkan kembali ke OS).

\* What-If 3: Tombol Back HP Ditekan (Batal / Mau Keluar)

* Ditahan oleh `PopScope` → memunculkan dialog modal berisi 3 pilihan:

    * "Tetap di Sini": Dialog tertutup, sesi dan musik tetap lanjut seperti biasa.

    * "Minimize": Menjalankan `SystemNavigator.pop()`, melempar aplikasi ke background HP tanpa mematikan timer & musik.

    * "Hentikan Sesi" (Batal Total):

        * Memanggil `timerService.stop()` (semua alarm dibatalkan, state lokal dihapus, status kembali ke `idle`).

        * Memanggil `mediaService.stopAmbience()` untuk menghentikan audio ambience. Pemanggilan ini tidak mengubah pilihan atau menghentikan video latar.

        * Sesi dibatalkan dan TIDAK dicatat ke Firebase. Aplikasi keluar.

### 5.3. Sesi Selesai Normal (`_onCompleted`)

* Ticker dihentikan dan `TimerService` memanggil `notifyListeners()` agar UI mengetahui status selesai.

* `MediaService.playAlarm()` dipanggil satu kali oleh `TimerService`; saat alarm berbunyi, volume ambience diturunkan sementara menjadi 20%.

* Setelah pemanggilan alarm, `TimerService` menonaktifkan wakelock dan menyimpan state timer.

* `TimerScreen` mendeteksi `isCompleted == true` → membuka modal `FinishSheet`. Layar tidak memutar alarm kedua kali; ketika sheet ditutup, `stopAlarm()` menghentikan alarm dan memulihkan volume ambience.

* Saat pergantian fase, `TimerService` juga memberi tahu listener terlebih dahulu, memutar alarm, lalu menyimpan state.

* Tes regresi engine memastikan sesi 1 menit berakhir dengan status `finished`.

### 5.4. Pengisian Refleksi & Simpan ke Firebase

* User mengisi catatan refleksi (opsional, maks. 280 karakter).

* Menekan tombol "Simpan & Selesai":

    * Data dibungkus ke model `SessionRecord` (`userId`, `durationMinutes`, `reflection`, timestamp `DateTime.now()`).

    * Dikirim ke `SessionRepository.createSession()` → diterjemahkan via `toMap()` → disimpan ke koleksi Firestore: `users/{uid}/sessions`.

    * `timerService.stop()` dipanggil untuk mereset timer ke `idle`.

    * Alarm dimatikan (`stopAlarm()`), modal ditutup, muncul SnackBar hijau, dan layar kembali ke tampilan awal.

### 5.5. What-If 4: Pengguna Ingin Logout (`_confirmLogout`)

1\. Konfirmasi Dialog:

* User menekan icon logout di AppBar `TimerScreen`.

* Muncul pop-up dialog peringatan: "Keluar Akun? Kamu akan keluar dari akun ini. Sesi yang sedang berjalan akan dihentikan."

* Ada 2 pilihan tombol: "Batal" atau "Keluar".

2\. Jika Memilih "Batal":

* Dialog ditutup (`Navigator.pop(ctx, false)`).

* Tidak ada efek apa pun; sesi timer dan audio tetap berjalan normal.

3\. Jika Memilih "Keluar" (`confirmed == true`): Sistem melakukan pembersihan total secara berurutan:

* Langkah 1 (Stop Timer): `timerService.stop()` dipanggil → detak timer mati, alarm notifikasi background di HP dibatalkan, memori cadangan lokal (`SharedPreferences`) dihapus, dan status kembali ke `idle`.

* Langkah 2 (Stop Media): `mediaService.stopAmbience()` dipanggil untuk menghentikan audio ambience. Pemanggilan ini tidak menghentikan atau melepas controller video.

* Langkah 3 (Sign Out Firebase): `authService.logout()` dipanggil → `FirebaseAuth.instance.signOut()` dijalankan untuk menghapus sesi login di perangkat.

* Langkah 4 (Otomatis Kembali ke Login): Stream `authStateChanges` mendeteksi data user berubah menjadi `null`. `AuthGate` langsung mengganti tampilan layar kembali ke `LoginScreen` seketika.

### 6\. Alur Riwayat Sesi (History, Edit & Hapus)

### 6.1. Masuk ke Layar Riwayat Sesi

* Dari AppBar `TimerScreen`, user menekan icon Riwayat (`Icons.history`).

* `Navigator.push` membuka layar `SessionsHistoryScreen`.

* Layar langsung berlangganan stream Firestore via `sessionRepo.watchRecentSessions(user.id, limit: 10)`:

    * Menampilkan 10 sesi terakhir secara real-time.

    * Setiap kartu menampilkan: icon otak/kopi, durasi fokus (menit), tanggal jam, dan cuplikan catatan refleksi.

### 6.2. Membuka Detail Sesi (`SessionDetailScreen`)

* User mengetuk/mengklik salah satu kartu sesi.

* Objek `SessionRecord` sesi tersebut dikirimkan ke `SessionDetailScreen`.

* Di layar detail ditampilkan:

    * Kartu status: Durasi fokus & tanggal jam lengkap (WIB).

    * Kolom teks formulir untuk membaca dan mengubah catatan refleksi.

    * Tombol icon sampah (delete) di AppBar kanan atas.

### 6.3. Alur Edit / Perbarui Refleksi (`_updateReflection`)

* User mengetik atau mengubah teks catatan di kolom refleksi.

* User menekan tombol "Perbarui Refleksi":

    * `_isSaving = true` (tombol dikunci agar tidak dobel klik).

    * Memanggil `sessionRepository.updateReflection(userId, sessionId, newText)`.

    * Firestore langsung meng-update field `'reflection'` pada dokumen sesi tersebut di path: `users/{uid}/sessions/{sessionId}`.

    * Muncul SnackBar: "Refleksi berhasil diperbarui."

    * Karena halaman riwayat sebelumnya memakai `StreamBuilder`, data teks di halaman riwayat otomatis ikut ter-update secara instan.

### 6.4. Alur Hapus Sesi (`_confirmDelete`)

* User menekan icon sampah (`Icons.delete_outline`) di AppBar.

* Konfirmasi: Muncul pop-up dialog: "Hapus Sesi? Sesi ini akan dihapus permanen dari riwayat." (Pilihan: Batal / Hapus).

* Jika memilih "Hapus":

    * `_isDeleting = true`.

    * Memanggil `sessionRepository.deleteSession(userId, sessionId)`.

    * Dokumen sesi tersebut dihapus secara permanen dari Cloud Firestore via `.delete()`.

    * `Navigator.pop(context)` menutup halaman detail dan kembali ke daftar riwayat.

    * Daftar kartu riwayat di `SessionsHistoryScreen` otomatis hilang 1 baris detik itu juga karena sifat real-time stream, disertai SnackBar: "Sesi telah dihapus."

### 7\. Alur Layar Statistik (`StatsScreen`)

### 7.1. Masuk ke Layar Statistik

* User menekan icon grafik/wawasan (`Icons.insights_outlined`) di AppBar `TimerScreen`.

* `Navigator.push` membuka layar `StatsScreen`.

### 7.2. Mengambil Data Mentah 30 Hari Terakhir

\* Di fungsi `initState` → `_loadStats()`:

* Mengambil tanggal sekarang (`now`) dan tanggal 30 hari ke belakang (`now - 30 hari`).

* Memanggil `SessionRepository.getSessionsForDateRange(userId, start, end)` untuk mendownload riwayat sesi 30 hari terakhir dari Firestore.

### 7.3. Perhitungan Otomatis oleh `StatsCalculator`

Di dalam `FutureBuilder`, daftar sesi mentah tersebut dioper ke `StatsCalculator.calculate(sessions)`:

* Hari Ini: Menjumlahkan menit fokus yang dikerjakan hari ini.

* Minggu Ini: Menjumlahkan menit fokus dalam 7 hari terakhir.

* Streak: Menghitung rekor belajar berturut-turut tanpa jeda bolong hari.

* Grafik 7 Hari: Mengelompokkan menit fokus per hari dari Senin s/d Minggu kemarin.

### 7.4. Menampilkan ke Layar UI

\* Jika Tidak Ada Aktivitas Minggu Ini (`stats.isEmpty`):

* Muncul tampilan kosong (empty state): "Selesaikan sesi fokus untuk melihat ringkasan waktu belajar...".

\* Jika Ada Data:

* Tampil 3 Kartu Metrik di atas: Fokus Hari Ini (menit), Fokus Minggu Ini (menit), dan Streak Belajar (hari).

* Tampil Grafik Batang 7 Hari Terakhir (`BarChartWidget`) yang digambar native tanpa library pihak ketiga.

* Ada fitur Tarik ke Bawah untuk Refresh (`RefreshIndicator`) agar data statistik bisa diperbarui ulang kapan saja.
