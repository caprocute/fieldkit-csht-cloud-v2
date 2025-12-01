# Hướng Dẫn Sử Dụng Báo Cáo LaTeX

## Cấu Trúc Thư Mục

```
thesis/
├── main.tex              # File chính, liên kết tất cả các chương
├── references.bib        # File tài liệu tham khảo
├── chapters/             # Thư mục chứa các chương
│   ├── vai-tro.tex       # Chương 1: Bảng phân chia vai trò
│   ├── gioi-thieu.tex    # Chương 2: Giới thiệu sản phẩm
│   ├── khao-sat.tex      # Chương 3: Khảo sát tổng quan
│   ├── dich-vu-cloud.tex # Chương 4: Giới thiệu dịch vụ đám mây
│   ├── so-sanh.tex       # Chương 5: Phân tích so sánh
│   ├── kien-truc.tex     # Chương 6: Sơ đồ kiến trúc
│   ├── trien-khai.tex    # Chương 7: Hướng dẫn triển khai
│   └── danh-gia.tex      # Chương 8: Đánh giá và kiểm thử
└── README.md             # File hướng dẫn này
```

## Yêu Cầu

- LaTeX distribution (TeX Live, MiKTeX, hoặc MacTeX)
- Các package cần thiết:
  - `babel` với option `vietnamese`
  - `mermaid` (cho sơ đồ)
  - `hyperref`, `graphicx`, `float`, `cite`, v.v.

## Cách Biên Dịch

### Trên Overleaf

1. Upload toàn bộ thư mục `thesis` lên Overleaf
2. Chọn `main.tex` làm file chính
3. Click "Compile" để biên dịch

### Trên Local Machine

```bash
# Biên dịch PDF
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex

# Hoặc sử dụng latexmk (khuyến nghị)
latexmk -pdf main.tex
```

## Cách Sử Dụng

### 1. Chỉnh Sửa Nội Dung

Mở các file `.tex` trong thư mục `chapters/` và điền nội dung vào các phần đã được đánh dấu.

### 2. Thêm Hình Ảnh

Để thêm hình ảnh, sử dụng mermaid.js trong môi trường `mermaid`:

```latex
\begin{mermaid}
graph TB
    A[Node 1] --> B[Node 2]
\end{mermaid}
```

Hoặc sử dụng `\includegraphics` cho hình ảnh thông thường:

```latex
\begin{figure}[H]
\centering
\includegraphics[width=0.8\textwidth]{path/to/image.png}
\caption{Mô tả hình ảnh}
\label{fig:label-name}
\end{figure}
```

### 3. Thêm Tài Liệu Tham Khảo

1. Thêm entry vào file `references.bib` theo format BibTeX
2. Sử dụng `\cite{key}` trong nội dung để trích dẫn
3. Chạy lại `bibtex` và `pdflatex` để cập nhật danh sách tài liệu tham khảo

### 4. Tách Chương Dài

Nếu một chương quá dài, có thể tách thành các file con:

```latex
% Trong file chương chính
\input{chapters/subsection1}
\input{chapters/subsection2}
```

## Lưu Ý

- **Font**: Times New Roman, Size 12 (đã cấu hình trong `main.tex`)
- **Spacing**: Single spacing (1.0) - đã cấu hình với `\onehalfspacing`
- **Justify**: Căn đều 2 bên - đã cấu hình mặc định
- **Hình ảnh**: Không quá nửa trang, không quá 10 hình mỗi 30 trang
- **Mục lục**: Tự động tạo từ `\tableofcontents`
- **Navigation**: Tự động từ hyperref package

## Troubleshooting

### Lỗi biên dịch mermaid
- Đảm bảo package `mermaid` đã được cài đặt
- Trên Overleaf, có thể cần sử dụng package khác hoặc export mermaid sang hình ảnh

### Lỗi encoding tiếng Việt
- Đảm bảo file được lưu với encoding UTF-8
- Kiểm tra package `babel` với option `vietnamese` đã được load

### Tài liệu tham khảo không hiển thị
- Chạy đầy đủ các bước: `pdflatex` → `bibtex` → `pdflatex` → `pdflatex`
- Kiểm tra file `references.bib` có đúng format

## Liên Hệ

Nếu có vấn đề, vui lòng liên hệ nhóm phát triển.

