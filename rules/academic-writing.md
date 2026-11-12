# Pedoman Penulisan Akademik

> Berlaku saat proyek aktif berisi naskah akademik (LaTeX, Markdown, atau Word).
> Bila sesi tidak menyentuh berkas `.tex`/`.bib`/naskah, abaikan seluruh berkas ini.

## 1. Larangan Membaca Log Mentah

- JANGAN pernah `cat`, `Read`, `tail`, atau `grep` berkas `.log` secara langsung. Satu log LaTeX bisa 3.000+ baris dan menghabiskan context window.
- Selalu gunakan tool MCP `thesis-latex`:
  - `compile_thesis(main_file="main.tex")` → exit code, baris `!` error + 3 baris konteks, serta `LaTeX Warning: Reference/Citation ... undefined` saja.
  - `check_bibtex(bib_file="daftar-pustaka.bib")` → duplikat key, entri tanpa author/title/year, total referensi.
  - `read_chapter(chapter_path="bab2.tex")` → baca satu bab tanpa memuat seluruh naskah.
- Bila `compile_thesis` gagal karena LaTeX belum terpasang, laporkan ke pengguna. Jangan membaca `.log` sebagai pengganti.

## 2. Penulisan Modular

- Edit selalu per file bab: `bab1.tex`, `bab2.tex`, dst. atau per file babak di `naskah/`.
- `main.tex` hanya boleh disentuh untuk: menambah/mengubah package di preamble, mengubah `\input{}`/`\include{}`, mengatur `\geometry`/font/template, atau konfigurasi bibliografi.
- Satu perubahan = satu file. Jangan menulis ulang beberapa bab sekaligus tanpa diminta.
- Setelah mengedit, jalankan `compile_thesis` untuk memastikan tidak menambah error baru.

## 3. Standar Gaya Penulisan

- Bahasa Indonesia baku akademik formal sesuai EYD: hindari kata lisan ("gimana", "banget", "kayak"), hindari "di mana" sebagai penghubung, gunakan "yaitu"/"yakni" secara tepat.
- Kalimat pasif-ilmiah untuk metode ("pengujian dilakukan"), aktif untuk kontribusi ("penelitian ini mengusulkan").
- Satu paragraf = satu gagasan pokok; paragraf maksimal ±150 kata.
- Hindari klaim tanpa rujukan, kata berlebihan ("sangat penting sekali"), dan generalisasi tanpa data.
- Istilah asing dicetak miring (`\textit{}`) pada kemunculan pertama, lalu konsisten.
- Angka: desimal dengan koma (3,14), ribuan dengan titik (1.000), satuan dipisah spasi (10 cm).

## 4. Konvensi Label dan Referensi

- Format label wajib: `eq:nama`, `fig:nama`, `tab:nama`, `sec:nama`, `lst:nama`, `app:nama` — huruf kecil, pemisah tanda hubung (`fig:arsitektur-sistem`).
- Setiap `\label{}` harus dirujuk minimal satu kali. Label yatim dihapus.
- Nomor persamaan yang dirujuk memakai `\eqref{}`, bukan `\ref{}`.
- Tabel dan gambar wajib punya `\caption` dan dirujuk di teks sebelum kemunculannya ("Gambar 3.1 menunjukkan ...").

## 5. Sitasi Wajib Terverifikasi

- Setiap `\cite{key}` harus punya entri nyata di file `.bib`. Jangan pernah menulis sitasi dari ingatan.
- Sebelum menambah sitasi baru, jalankan `check_bibtex`; setelah menambah entri, jalankan ulang untuk memastikan tidak ada duplikat.
- Field minimum per entri: `author`, `title`, `year`, dan `doi` bila tersedia.
- Bila DOI/penulis tidak dapat diverifikasi ke sumber asli, tandai entri dengan komentar `% UNVERIFIED` dan laporkan ke pengguna. Jangan mengarang metadata.
- Jalankan `compile_thesis` setelah perubahan `.bib`; seluruh `Citation ... undefined` harus nol sebelum tugas dinyatakan selesai.

## 6. Kriteria Selesai

Sebuah tugas penulisan dianggap selesai hanya bila:
1. `compile_thesis` exit code 0 dan PDF terbentuk (untuk proyek LaTeX).
2. Nol error `!`, nol `Reference ... undefined`, nol `Citation ... undefined`.
3. `check_bibtex` tanpa duplikat dan tanpa entri yang kehilangan field wajib.
