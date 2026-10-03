# 🖥️ SystemCheck — Kiểm Tra Lỗi Hệ Thống

> **Mục đích:** Phát hiện nguyên nhân máy tính tự động tắt hoặc khởi động lại bất thường khi đang xem phim / chạy ứng dụng.

---

## 📁 Cấu Trúc Project

```raw
SystemCheck/
├── SystemCheck.bat          ← Chạy chính (cần Admin)
├── QuickCheck.bat           ← Kiểm tra nhanh (không cần Admin)
├── Setup.bat                ← Cài đặt lần đầu (tạo shortcut, task tự động)
├── scripts/
│   └── CheckSystemErrors.ps1  ← Engine phân tích PowerShell
├── reports/                 ← Báo cáo HTML được lưu ở đây
├── logs/                    ← Log văn bản được lưu ở đây
└── README.md
```

---

## 🚀 Cách Sử Dụng

### Lần đầu (cài đặt):
1. Chuột phải vào **`Setup.bat`** → **"Run as administrator"**
2. Script sẽ tạo shortcut trên Desktop và task tự động quet mỗi khi khởi động

### Kiểm tra đầy đủ:
1. Chuột phải vào **`SystemCheck.bat`** → **"Run as administrator"**
2. Chọn **1** để quét lỗi hệ thống/Event Log hoặc **2** để kiểm tra phần cứng tối đa
3. Chờ script quét xong
4. Chọn **Y** khi được hỏi để mở báo cáo HTML

Kiểm tra phần cứng thu thập thông tin CPU, RAM, GPU, ổ đĩa, pin, thiết bị có lỗi,
sự kiện WHEA và nhiệt độ nếu Windows cung cấp. Đây là kiểm tra chỉ đọc; khả năng
đọc SMART và cảm biến phụ thuộc driver/phần cứng. Script không chạy stress test.

### Kiểm tra nhanh (console):
```bat
QuickCheck.bat          ← Quét 7 ngày gần nhất
QuickCheck.bat 30       ← Quét 30 ngày gần nhất
```

---

## 🔍 Những Gì Script Kiểm Tra

| Danh mục | Event ID | Mô tả |
|---|---|---|
| ⚡ Tắt đột ngột | **ID 41** (Kernel-Power) | Mất điện, CPU/GPU quá nhiệt, nguồn yếu |
| 💥 Dirty Shutdown | **ID 6008** (EventLog) | Ghi nhận sau boot lại khi tắt bất thường |
| 🟢 Tắt bình thường | **ID 6006** | Shutdown đúng quy trình |
| 🔵 Khởi động | **ID 6005** | Windows bắt đầu boot |
| 🔄 App Shutdown | **ID 1074** | Chương trình hoặc người dùng tắt máy |
| 💣 BSOD | **ID 1001** + Minidump | Màn hình xanh, crash kernel |
| 💾 Lỗi ổ đĩa | **ID 7, 9, 11, 51** | I/O error, ổ cứng sắp hỏng |
| 📁 Lỗi NTFS | **ID 55, 50** | Filesystem bị hỏng |
| ⚙️ Dịch vụ crash | **ID 7031, 7034** | Service bị dừng đột ngột |
| 🔄 Windows Update | **ID 19-34** | Update tự động khởi động lại |

---

## 📊 Báo Cáo HTML

Báo cáo được lưu tại `reports/SystemReport_YYYYMMDD_HHMMSS.html` gồm:

- **Stat cards** — số lần tắt đột ngột, BSOD, lỗi đĩa
- **Chẩn đoán** — phân tích nguyên nhân với khuyến nghị
- **Timeline** — 100 sự kiện gần nhất theo thứ tự thời gian
- **Danh sách minidump** — BSOD crash files
- **Tình trạng ổ đĩa** — dung lượng từng ổ
- **Nhiệt độ** — (nếu WMI sensor khả dụng)
- **Hướng dẫn khắc phục** — lệnh và phần mềm gợi ý

---

## 🌡️ Nguyên Nhân Phổ Biến Máy Tự Tắt

| Nguyên nhân | Dấu hiệu | Cách kiểm tra |
|---|---|---|
| **Mất điện / điện không ổn** | ID 41 nhiều lần | Mua UPS hoặc AVR |
| **CPU/GPU quá nhiệt** | ID 41 khi đang dùng nặng | HWiNFO64, vệ sinh tản nhiệt |
| **Nguồn (PSU) yếu/lỗi** | ID 41 không theo pattern | Đổi PSU, kiểm tra kết nối |
| **RAM lỗi** | BSOD ngẫu nhiên | MemTest86 (test qua đêm) |
| **Ổ cứng sắp hỏng** | ID 9, 11, 51 | CrystalDiskInfo S.M.A.R.T |
| **Windows Update** | ID 1074 / 1076 | Tắt auto-restart trong Settings |
| **Driver lỗi** | BSOD + tên driver trong minidump | WhoCrashed, cập nhật driver |

---

## 🛠️ Lệnh Hữu Ích Sau Khi Phát Hiện Lỗi

```powershell
# Kiểm tra file hệ thống
sfc /scannow

# Sửa ảnh Windows
DISM /Online /Cleanup-Image /RestoreHealth

# Kiểm tra ổ đĩa (khởi động lại để chạy)
chkdsk C: /f /r

# Xem báo cáo nguồn điện
powercfg /energy
powercfg /sleepstudy

# Kiểm tra RAM (mở Windows Memory Diagnostic)
mdsched.exe

# Xem Event Viewer trực tiếp
eventvwr.msc
```

---

## ⚙️ Yêu Cầu Hệ Thống

- **Windows 10 / 11** (Windows 7+ cũng hoạt động)
- **PowerShell 5.1+** (có sẵn trên Windows 10+)
- **Quyền Administrator** (để đọc Event Log đầy đủ)

---

## 📌 Ghi Chú

- Script **không thay đổi** bất kỳ cài đặt hệ thống nào — chỉ đọc log
- Dữ liệu Event Log giữ nguyên trên máy, không gửi đi đâu
- Báo cáo cũ không bị xóa (mỗi lần chạy tạo file mới với timestamp)
- Để đặt lịch quet hàng tuần thêm vào Task Scheduler thủ công

---

*Được tạo bởi **AntiGravity System Monitor** | Phiên bản 2.0*
