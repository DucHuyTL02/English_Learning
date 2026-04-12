# PREMIUM GATE PLAN – Khóa bài học theo gói Premium

## 1. Tổng quan

Người dùng **miễn phí** chỉ được học **bài đầu tiên** (lesson có `sortOrder = 1` trong unit đầu tiên).  
Muốn mở khóa **toàn bộ bài học còn lại**, người dùng phải mua gói Premium.

### Luồng trải nghiệm

```
                    ┌─────────────────┐
                    │   Đăng ký/Login  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   Home Screen    │
                    │  (Bài 1: FREE)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───────┐     │    ┌─────────▼─────────┐
     │ Hoàn thành      │     │    │ Nhấn bài 2+       │
     │ Bài 1 → OK      │     │    │ → LockedLessonDialog│
     └────────┬───────┘     │    │ → SubscriptionScreen│
              │              │    └─────────────────────┘
              │              │
     ┌────────▼───────┐     │
     │ Bài 2 trở đi?  │     │
     │ isPremium?      │─NO─┘
     │                 │
     │ YES → Mở khóa  │
     └────────────────┘
```

---

## 2. Gói Premium

| Gói         | Code       | Giá (VNĐ)  | Thời hạn | Ghi chú           |
|-------------|------------|-------------|----------|--------------------|
| **Gói Tháng** | `monthly`  | 99.000₫     | 30 ngày  |                    |
| **Gói Năm**   | `yearly`   | 599.000₫    | 365 ngày | Tiết kiệm ~50%    |

---

## 3. Thay đổi cần thực hiện

### PHASE 1: Model & Database

#### 3.1. `UserModel` – Thêm trường Premium
File: `lib/data/models/user_model.dart`

```dart
// Thêm các field:
bool isPremium;          // true nếu đang có gói Premium
DateTime? premiumExpiresAt; // Ngày hết hạn Premium (null = chưa mua)
String subscriptionPlan; // 'monthly' | 'yearly' | '' (chưa mua)
```

Thêm getter:
```dart
bool get isActivePremium =>
    isPremium && premiumExpiresAt != null && premiumExpiresAt!.isAfter(DateTime.now());
```

#### 3.2. `AppDatabase` – Migration v4 → v5
File: `lib/data/app_database.dart`

- Thêm 3 cột mới vào bảng `users`:
  - `is_premium` INTEGER DEFAULT 0
  - `premium_expires_at` TEXT (nullable)
  - `subscription_plan` TEXT DEFAULT ''
- Tăng `_version` từ 4 lên 5.

---

### PHASE 2: Logic khóa bài học

#### 3.3. `LearningRepository` – Thêm kiểm tra quyền truy cập
File: `lib/data/repositories/learning_repository.dart`

Thêm method:
```dart
/// Trả về true nếu user được phép học lesson này.
/// Quy tắc: Bài đầu tiên (sortOrder = 1, unitId = 1) luôn FREE.
///          Tất cả bài còn lại yêu cầu Premium.
Future<bool> canAccessLesson(int lessonId, UserModel user) async {
  final lesson = await _db.query('lessons', where: 'id = ?', whereArgs: [lessonId]);
  if (lesson.isEmpty) return false;
  final sortOrder = lesson.first['sort_order'] as int;
  final unitId = lesson.first['unit_id'] as int;
  // Bài đầu tiên của unit đầu tiên → miễn phí
  if (unitId == 1 && sortOrder == 1) return true;
  // Còn lại → cần Premium
  return user.isActivePremium;
}
```

#### 3.4. `UserRepository` – Cập nhật Premium
File: `lib/data/repositories/user_repository.dart`

Thêm method:
```dart
/// Kích hoạt Premium cho user (gọi sau khi thanh toán thành công).
Future<void> activatePremium({
  required int userId,
  required String plan, // 'monthly' | 'yearly'
}) async {
  final days = plan == 'yearly' ? 365 : 30;
  final expiresAt = DateTime.now().add(Duration(days: days));
  await _db.update('users', {
    'is_premium': 1,
    'premium_expires_at': expiresAt.toIso8601String(),
    'subscription_plan': plan,
  }, where: 'id = ?', whereArgs: [userId]);
}

/// Kiểm tra & tắt Premium nếu đã hết hạn.
Future<void> checkAndExpirePremium(int userId) async {
  final user = await getUserById(userId);
  if (user != null && user.isPremium && !user.isActivePremium) {
    await _db.update('users', {
      'is_premium': 0,
      'subscription_plan': '',
    }, where: 'id = ?', whereArgs: [userId]);
  }
}
```

---

### PHASE 3: UI – Khóa bài học

#### 3.5. `HomeScreen` – Hiển thị ổ khóa trên bài bị khóa
File: `lib/screens/home_screen.dart`

Thay đổi trong `_NextLessonCard` và `_LearningPathMap`:
- Nếu bài tiếp theo **không phải bài 1** và user **không có Premium**:
  - Hiển thị icon 🔒 thay vì icon bài học
  - Nút "Bắt Đầu Bài Học" → đổi thành "🔒 Mở Khóa Premium"
  - Nhấn nút → chuyển đến `/subscription`
- Trong bản đồ học tập (`_LearningPathMap`):
  - Bài đã hoàn thành: ✅ (giữ nguyên)
  - Bài đang học (FREE): hiển thị bình thường
  - Bài bị khóa: hiển thị icon 🔒 với màu xám, nhấn → dialog thông báo

#### 3.6. `LessonIntroScreen` – Gate check trước khi vào bài
File: `lib/screens/lesson_screen.dart`

Khi mở `/lesson-intro/:lessonId`:
1. Gọi `canAccessLesson(lessonId, user)`
2. Nếu `false` → hiển thị `_LockedLessonDialog`:
   - Title: "🔒 Bài học bị khóa"
   - Body: "Nâng cấp Premium để mở khóa toàn bộ bài học!"
   - Nút "Xem gói Premium" → `/subscription`
   - Nút "Quay lại" → pop
3. Nếu `true` → hiển thị bình thường

#### 3.7. `CourseMapScreen` – Hiển thị trạng thái khóa
File: `lib/screens/lesson_screen.dart` (CourseMapScreen)

Mỗi lesson node trên bản đồ:
- **FREE (bài 1)**: hiển thị bình thường, có thể tap
- **LOCKED**: icon 🔒, overlay mờ, tap → `_LockedLessonDialog`
- **UNLOCKED (Premium)**: hiển thị bình thường, có thể tap

---

### PHASE 4: SubscriptionScreen cải tiến

#### 3.8. `SubscriptionScreen` – Giao diện chọn gói
File: `lib/screens/utility_screens.dart`

Chuyển từ `StatelessWidget` → `ConsumerStatefulWidget`:
- Hiển thị 2 gói (Tháng / Năm) với selector
- Nút thanh toán (placeholder – để sau tích hợp cổng thanh toán)
- Nếu user đã có Premium → hiển thị trạng thái "Premium đang hoạt động" + ngày hết hạn
- Nếu chưa có → hiển thị danh sách tính năng + nút mua
- **Tạm thời**: nút "Kích hoạt Premium" sẽ gọi `activatePremium()` trực tiếp (mock) để test flow

---

### PHASE 5: Provider & State

#### 3.9. `activeUserProvider` – Kiểm tra Premium khi khởi động
File: `lib/data/providers/app_providers.dart`

Khi `build()` hoặc `refresh()`:
```dart
// Kiểm tra hết hạn Premium mỗi khi load user
await AppServices.userRepository.checkAndExpirePremium(user.id!);
```

---

## 4. Danh sách file cần thay đổi (theo thứ tự)

| #  | File                                       | Hành động      | Mô tả                                           |
|----|-------------------------------------------|----------------|--------------------------------------------------|
| 1  | `lib/data/models/user_model.dart`          | Sửa            | Thêm 3 field Premium + getter `isActivePremium`  |
| 2  | `lib/data/app_database.dart`               | Sửa            | Migration v5: thêm 3 cột Premium vào `users`     |
| 3  | `lib/data/repositories/learning_repository.dart` | Sửa      | Thêm `canAccessLesson()`                         |
| 4  | `lib/data/repositories/user_repository.dart`     | Sửa      | Thêm `activatePremium()`, `checkAndExpirePremium()` |
| 5  | `lib/data/providers/app_providers.dart`    | Sửa            | Gọi `checkAndExpirePremium()` khi load user      |
| 6  | `lib/screens/home_screen.dart`             | Sửa            | Khóa bài 2+ trên NextLessonCard & LearningPath   |
| 7  | `lib/screens/lesson_screen.dart`           | Sửa            | Gate check tại LessonIntroScreen & CourseMapScreen |
| 8  | `lib/screens/utility_screens.dart`         | Sửa            | SubscriptionScreen → chọn gói + mock activate     |

---

## 5. Quy tắc nghiệp vụ

| Quy tắc                          | Chi tiết                                                      |
|----------------------------------|--------------------------------------------------------------|
| Bài miễn phí                     | Chỉ bài có `unitId == 1 && sortOrder == 1`                   |
| Premium hết hạn                  | `isPremium` tự động chuyển `false` khi `premiumExpiresAt` quá hạn |
| Kiểm tra hết hạn                 | Mỗi lần app mở hoặc load user → gọi `checkAndExpirePremium` |
| Bài đã hoàn thành trước khi hết hạn | Vẫn giữ tiến độ (user_progress), nhưng không mở bài mới    |
| Mock thanh toán (tạm thời)        | Gọi `activatePremium()` trực tiếp, không cần cổng thanh toán |

---

## 6. Giao diện minh họa

### Bài bị khóa (Home Screen)
```
┌──────────────────────────────────┐
│  🔒  Bài 2: Gia Đình             │
│  Unit: Cơ Bản                     │
│                                    │
│  ┌──────────────────────────────┐ │
│  │  🔒 Mở Khóa Premium          │ │
│  └──────────────────────────────┘ │
│  Nâng cấp để tiếp tục học!        │
└──────────────────────────────────┘
```

### Dialog khóa bài
```
┌────────────────────────────────┐
│         🔒                      │
│   Bài học bị khóa               │
│                                  │
│   Nâng cấp Premium để mở khóa   │
│   toàn bộ 12 bài học và tính     │
│   năng nâng cao!                 │
│                                  │
│   [  Xem gói Premium  ]         │
│   [    Quay lại       ]         │
└────────────────────────────────┘
```

---

## 7. Lưu ý khi triển khai

1. **Không xóa tiến độ** khi Premium hết hạn — chỉ chặn truy cập bài mới.
2. **Không cần backend** cho phase này — toàn bộ logic chạy local (SQLite).
3. **Mock payment** cho phép test toàn bộ flow mà không cần tích hợp cổng thanh toán.
4. **Sau này** khi tích hợp MoMo/ZaloPay/Stripe → chỉ cần thay thế lệnh `activatePremium()` mock bằng lệnh gọi cổng thanh toán thật, không cần sửa logic khóa bài.
