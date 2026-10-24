# App Store Connect → App Privacy (Kiếm Hiệp Ngũ Hành)

Trả lời "Có, app thu thập dữ liệu", rồi khai các loại sau.

| Loại dữ liệu (App Store) | Ai thu | Liên kết người dùng | Dùng để theo dõi (tracking) | Mục đích |
|---|---|---|---|---|
| Contact Info → Email Address | Firebase Auth khi đăng nhập Google/Apple | Có | Không | App Functionality |
| Identifiers → User ID | Firebase (mã tài khoản) | Có | Không | App Functionality |
| Identifiers → Device ID | AdMob (IDFA, chỉ khi người chơi cho phép ATT) | Không | **Có** | Third-Party Advertising |
| User Content → Gameplay Content | Bản lưu trên mây, bảng xếp hạng (tên nhân vật, cấp, lực chiến, tầng tháp) | Có | Không | App Functionality |
| Usage Data → Product Interaction | AdMob, Firebase Analytics (từ 1.0.7) | Không | Có (AdMob) | Third-Party Advertising, Analytics |
| Usage Data → Advertising Data | AdMob | Không | Có | Third-Party Advertising |
| Location → Coarse Location | AdMob (ước lượng từ IP) | Không | Có | Third-Party Advertising |
| Diagnostics → Crash Data, Performance Data | AdMob SDK | Không | Không | Analytics |

Ghi chú:
- Vì có dòng "Dùng để theo dõi = Có", app phải hỏi App Tracking Transparency: đã có từ bản 1.0.6+9.
- Game không thu tên thật, số điện thoại, danh bạ, ảnh hay vị trí chính xác.
- Privacy Policy URL: https://nttqn.github.io/kiem-hiep-app/privacy.html
- Ghi chú cho người duyệt: dán nội dung `store/appstore-review-notes.txt` vào App Review Information → Notes. Không cần tài khoản demo (bỏ trống, bỏ chọn "Sign-in required").
