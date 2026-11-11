# Daftar Masalah & Analisis Bug (Release Build & Timer Flow)

Dokumen ini merangkum analisis mendalam dari dua rangkaian masalah yang ditemukan saat pengujian build rilis (`flutter build apk --split-per-abi`).

---

## 1. Bug: Durasi Terkunci Setelah Menghapus Custom Duration & Template Chip Tidak Berfungsi

### Gejala
- Pada mode rilis APK, saat teks input durasi custom dihapus hingga kosong (`""`), pilihan durasi menjadi terkunci.
- Pengguna tidak bisa mengubah durasi lagi dengan mengetuk template chip preset (`15m`, `30m`, `45m`, `60m`).

### Lokasi Kode
- `lib/features/timer/timer_screen.dart` (pada `didChangeDependencies`, `ChoiceChip.onSelected`, dan `TextField.onChanged`)

### Penyebab Utama
1. **Loop Penimpaan Teks di `didChangeDependencies`:**
   - Di baris 46–48 `timer_screen.dart`, terdapat sinkronisasi satu arah:
     ```dart
     if (_durationInputController.text != timerService.totalSessionMinutes.toString()) {
       _durationInputController.text = timerService.totalSessionMinutes.toString();
     }
     ```
   - Ketika teks dihapus sampai kosong (`""`), `TextField.onChanged` gagal mem-parse (`int.tryParse("")` mengembalikan `null`), sehingga `timerService.setTotalMinutes()` tidak pernah dipanggil. Nilai di `TimerService` tetap pada angka lama.
2. **Tabrakan Event di Mode Release:**
   - Pada build rilis (AOT compilation), event microtask dan dispatch listener berjalan jauh lebih cepat dibanding mode debug.
   - Saat pengguna mengetuk template chip, `onSelected` mengubah teks controller sekaligus memanggil `setTotalMinutes()`.
   - Notifikasi listener langsung memicu re-render dan eksekusi `didChangeDependencies()`. Jika kursor input masih aktif (editing/composing IME) atau ada delay sinkronisasi nilai, controller teks ditimpa kembali secara agresif, menyebabkan nilai terkunci dan chip tampak tidak merespons.

---

## 2. Bug: Timer Langsung Berhenti / Selesai Seketika & Tombol "Jeda" Tidak Berfungsi

### Gejala
- Setelah durasi custom berada dalam kondisi kosong/terkunci lalu tombol "Mulai" ditekan, timer tidak berjalan normal.
- Tombol "Jeda" tidak dapat diklik atau tidak ada respons.
- Menekan tombol "Batal" langsung menghentikan timer.

### Lokasi Kode
- `lib/features/timer/timer_screen.dart` (`_buildControlButtons`)
- `lib/services/timer_engine.dart` (`_generatePlans` dan `remainingDuration`)
- `lib/services/timer_service.dart` (`_startTicker`)

### Penyebab Utama
1. **Durasi Tidak Valid / Instant Expire:**
   - Karena input kosong tidak memiliki nilai default fallback yang aman sebelum sesi dimulai, nilai durasi masuk dalam status minimum atau nol.
   - Begitu `start()` dipanggil, waktu berakhir (`_endAt`) langsung terlewati atau sama dengan waktu saat ini (`DateTime.now()`).
   - Pada tick pertama (`_ticker`), `TimerEngine` mendeteksi bahwa waktu sudah habis dan status langsung berpindah dari `running` ke `finished`.
2. **Kondisi State Tombol Kontrol:**
   - Tombol "Jeda" hanya aktif saat `timerService.isRunning` bernilai `true`.
   - Karena status sudah langsung melompat menjadi `finished` atau kembali `idle`, kontrol jeda tidak lagi berfungsi sebagaimana mestinya.
   - Tombol "Batal" mengeksekusi `timerService.stop()`, yang secara eksplisit mereset engine ke kondisi awal.

---

## 3. Bug: Dialog Back Interception ("Tetap di Sini" / "Hentikan Sesi") Tidak Berdampak pada Navigasi

### Gejala
- Ketika tombol fisik/gesture back Android ditekan saat sesi berjalan, dialog konfirmasi muncul.
- Memilih opsi "Tetap di Sini" maupun "Hentikan Sesi" tidak mengarahkan navigasi keluar; pengguna tetap tertahan di layar yang sama seolah tombol tidak berefek.

### Lokasi Kode
- `lib/features/timer/timer_screen.dart` (`_onWillPop`)

### Penyebab Utama
1. **Tidak Ada Aksi Navigasi Setelah Menghentikan Sesi:**
   - Pada method `_onWillPop`:
     ```dart
     if (result == 'stop') {
       await timerService.stop();
       await mediaService.stopAmbience();
     }
     ```
   - Setelah timer dan audio dimatikan, dialog memang tertutup (`Navigator.pop(ctx, 'stop')`), tetapi kode **tidak memanggil navigasi keluar** (`Navigator.of(context).pop()` atau `SystemNavigator.pop()`). Akibatnya, aplikasi tetap berada di `TimerScreen`.
2. **Opsi "Minimize" Belum Tersedia:**
   - Dialog saat ini hanya memiliki dua tombol ("Tetap di Sini" dan "Hentikan Sesi").
   - Belum ada opsi "Minimize" yang memanggil `SystemNavigator.pop()` untuk mengirim aplikasi ke background tanpa mematikan audio dan timer.

---

## 4. Bug: Gagal Menyimpan Sesi di Release APK (`PlatformException: Type token must be created...`)

### Gejala
- Pada mode rilis APK (`flutter build apk --split-per-abi`), saat timer selesai dan pengguna menekan tombol simpan sesi pada *Finish Sheet*, muncul error SnackBar:
  > *"Gagal menyimpan sesi: PlatformException(... Type token must be created with a type parameter: new TypeToken<...>() ...)"*
- Data sesi gagal tersimpan ke Cloud Firestore.

### Lokasi Kode
- `lib/features/timer/widgets/finish_sheet.dart` (`_saveSession`)
- `lib/data/repositories/session_repository.dart` (`createSession`)
- `android/app/build.gradle.kts` (konfigurasi build type release & R8/ProGuard)

### Penyebab Utama
1. **R8 Code Shrinking / Obfuscation Menghapus Generic Signatures:**
   - Pada build release, Android Gradle Plugin menjalankan R8 untuk mengecilkan ukuran (*shrinking*) dan mengaburkan (*obfuscation*) bytecode Java/Kotlin.
   - Library native Firebase Firestore di Android memanfaatkan reflection dan type token (seperti Gson / Guava `TypeToken`) saat men-serialize payload data `Map<String, dynamic>` dan `Timestamp` dari Dart.
   - Tanpa aturan keep ProGuard, R8 menghapus metadata generic signature saat kompilasi. Saat runtime, pemanggilan `new TypeToken<T>()` kehilangan parameter tipe aslinya sehingga memicu `IllegalStateException` / `IllegalArgumentException: Type token must be created with a type parameter`.
2. **Ketiadaan Konfigurasi ProGuard Rules:**
   - Project belum memiliki file `android/app/proguard-rules.pro` yang secara eksplisit mempertahankan (*keep*) metadata generic signature, anotasi, dan class serializer Firebase/Firestore (`-keepattributes Signature, *Annotation*`, dsb.).

