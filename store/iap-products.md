# Gói IAP: tên và mô tả 4 ngôn ngữ

Play Console: Sản phẩm trong ứng dụng → mỗi sản phẩm → Thêm bản dịch (vi-VN, en-US, zh-TW, ko-KR).
Giới hạn Play: tên ≤ 55, mô tả ≤ 200 ký tự. App Store Connect: tên hiển thị ≤ 30, mô tả ≤ 45 ký tự.
Icon: 512px trong build/shots/iap_<id>.png (`flutter test tool/iap_icons_test.dart`), 1024px trong store/iap-icons-1024/.

Rương/Kho Ngân Lượng chỉ hiện trong Ưu đãi từ cấp 80 hoặc sau chuyển sinh. Lượng = Hòm Ngân Lượng
(100k + 10k·cấp)·(1 + chuyển sinh) × 6 hoặc × 15; ở lv99 CS6: 7,63M / 45,8M / 114,5M.

## kh_bo_quang_cao

Không tiêu hao (Non-consumable)

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Bỏ quảng cáo | Tắt quảng cáo khi về thành hay mở lại game, và nhận ngay mọi phần thưởng "xem quảng cáo" mà không phải xem. Áp dụng cho cả tài khoản, mọi nhân vật. Mua một lần, cài lại vẫn giữ. | Tắt quảng cáo, nhận thưởng QC ngay |
| en | Remove Ads | No more ads in town or on launch, and every "watch an ad" reward is yours at once without watching. For the whole store account and every hero. Buy once, kept after reinstalling. | No ads; ad rewards given instantly |
| zh-TW | 移除廣告 | 回城與開啟遊戲時不再出現廣告，所有「觀看廣告」獎勵免看直接領取。適用整個帳號的所有角色。一次購買，重新安裝仍保留。 | 移除廣告，廣告獎勵直接領取 |
| ko | 광고 제거 | 마을 귀환과 게임 시작 시 광고가 사라지고, 모든 "광고 보기" 보상을 시청 없이 바로 받습니다. 계정의 모든 캐릭터에 적용. 한 번 구매, 재설치 후에도 유지. | 광고 제거, 광고 보상 즉시 지급 |

## kh_nguyet_the

Tiêu hao (Consumable)

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Nguyệt thẻ | 30 ngày cho nhân vật đang chơi. Mỗi ngày nhận lượng, 2 viên ngọc, Thần Thiết (sau chuyển sinh), thêm 1 lượt Bí cảnh và 1 lượt Boss Thế Giới. Mua tiếp để cộng dồn ngày. | 30 ngày: lượng, ngọc, thêm lượt mỗi ngày |
| en | Monthly Card | 30 days for the current hero. Every day: gold, 2 gems, Divine Iron (after a rebirth), plus 1 extra Secret Realm and 1 extra World Boss run. Buy again to add more days. | 30 days of daily gold, gems, extra runs |
| zh-TW | 月卡 | 為目前角色提供 30 天。每天領取銀兩、2 顆寶石、神鐵（轉生後），並額外增加 1 次秘境與 1 次世界首領挑戰。再次購買可累加天數。 | 30 天每日銀兩、寶石與額外次數 |
| ko | 월정액 | 현재 캐릭터에게 30일간 적용. 매일 냥, 보석 2개, 신철(환생 후), 비경 1회와 월드 보스 1회 추가. 재구매 시 기간 누적. | 30일간 매일 냥, 보석, 추가 도전 |

## kh_goi_tan_thu

Tiêu hao, mỗi nhân vật 1 lần (Consumable, once per hero)

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Gói tân thủ | Một lần cho mỗi nhân vật: thú cưỡi Bạch Mã, 1 trang bị Sử thi theo cấp, 100.000 lượng, 50 Kim Sang Dược, 30 Ngưng Thần Đan và 3 viên ngọc bậc 2. | Bạch Mã, đồ Sử thi, lượng và ngọc |
| en | Starter Pack | Once per hero: the White Horse mount, 1 Epic gear piece for your level, 100,000 gold, 50 Wound Salves, 30 Spirit Pills and 3 tier 2 gems. | White Horse, Epic gear, gold and gems |
| zh-TW | 新手禮包 | 每個角色限購一次：坐騎白馬、1 件符合等級的史詩裝備、100,000 銀兩、50 金創藥、30 凝神丹與 3 顆 2 階寶石。 | 白馬、史詩裝備、銀兩與寶石 |
| ko | 신규 패키지 | 캐릭터당 1회: 탈것 백마, 레벨에 맞는 에픽 장비 1개, 냥 100,000, 금창약 50개, 응신단 30개, 2단계 보석 3개. | 백마, 에픽 장비, 냥과 보석 |

## kh_goi_thang_tinh

Tiêu hao, mỗi tuần 1 lần (Consumable, weekly)

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Gói Thăng Tinh | Mỗi tuần một lần cho nhân vật đang chơi: 120 Tinh Thạch và 3 Hung Thú Tinh Phách để nâng sao trang bị, tới ★10. | 120 Tinh Thạch + 3 Tinh Phách mỗi tuần |
| en | Star Pack | Once a week for the current hero: 120 Star Stones and 3 Beast Souls to raise your gear's stars, up to ★10. | 120 Star Stones + 3 Beast Souls weekly |
| zh-TW | 升星禮包 | 目前角色每週限購一次：120 星石與 3 凶獸精魄，用於裝備升星，最高 ★10。 | 每週 120 星石 + 3 凶獸精魄 |
| ko | 승성 패키지 | 현재 캐릭터 주 1회: 장비 승성용 성석 120개와 흉수정백 3개, 최대 ★10. | 매주 성석 120개 + 흉수정백 3개 |

## kh_lenh_bai

Tiêu hao, mỗi mùa 1 lần (Consumable, once per season)

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Lệnh Bài Hào Kiệt | Mở nhánh Hào Kiệt của mùa Lệnh Bài đang chạy cho nhân vật đang chơi. Bậc đã đạt nhận ngay: Tinh Thạch, Mảnh Hoàng Kim, ngọc Thánh, Tinh Phách, Tẩy Tủy Đan; bậc 30 có ngoại trang và danh hiệu. | Mở thưởng Hào Kiệt của mùa hiện tại |
| en | Hero Token | Opens this season's Hero track for the current hero. Tiers reached pay out at once: Star Stones, Gold Shards, Holy gems, Beast Souls, Marrow Pills; tier 30 adds an outfit and a title. | Unlocks this season's Hero rewards |
| zh-TW | 豪傑令牌 | 為目前角色開啟本季令牌的豪傑獎勵線，已達成的階級立即領取：星石、黃金碎片、聖階寶石、凶獸精魄、洗髓丹；第 30 階送外裝與稱號。 | 開啟本季豪傑獎勵 |
| ko | 호걸 영패 | 현재 캐릭터에게 진행 중인 시즌의 호걸 보상 라인을 개방. 달성한 단계는 즉시 수령: 성석, 황금 조각, 성(聖) 보석, 흉수정백, 세수단. 30단계에 외형과 칭호. | 이번 시즌 호걸 보상 개방 |

## kh_goi_le_hoi

Tiêu hao, mỗi lễ hội 1 lần (Consumable, once per festival)

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Gói lễ hội | Một lần mỗi lễ hội cho nhân vật đang chơi: 800 đồng xu lễ hội để đổi quà trong tiệm lễ hội, kèm 30 Tinh Thạch. Chỉ bán khi lễ hội đang diễn ra. | 800 xu lễ hội + 30 Tinh Thạch |
| en | Festival Pack | Once per festival for the current hero: 800 festival coins to spend in the festival shop, plus 30 Star Stones. On sale only while a festival runs. | 800 festival coins + 30 Star Stones |
| zh-TW | 節慶禮包 | 每次節慶目前角色限購一次：800 枚節慶貨幣可在節慶商店兌換獎勵，加贈 30 星石。僅於節慶期間販售。 | 800 節慶貨幣 + 30 星石 |
| ko | 축제 패키지 | 축제마다 현재 캐릭터 1회: 축제 상점에서 쓸 축제 화폐 800개와 성석 30개. 축제 기간에만 판매. | 축제 화폐 800개 + 성석 30개 |

## kh_hom_ngan_luong

Tiêu hao (Consumable) · 49.000 ₫

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Hòm Ngân Lượng | Lượng cho nhân vật đang chơi, tăng theo cấp và số lần chuyển sinh. Mua bao nhiêu lần cũng được. | Lượng tăng theo cấp và chuyển sinh |
| en | Gold Chest | Gold for the current hero, growing with level and rebirths. Buy as often as you like. | Gold that grows with level and rebirths |
| zh-TW | 銀兩寶箱 | 為目前角色提供銀兩，隨等級與轉生次數提高。可重複購買。 | 銀兩隨等級與轉生提高 |
| ko | 냥 상자 | 현재 캐릭터에게 냥 지급, 레벨과 환생 횟수에 따라 증가. 반복 구매 가능. | 레벨과 환생에 따라 늘어나는 냥 |

## kh_ruong_ngan_luong

Tiêu hao (Consumable) · 199.000 ₫

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Rương Ngân Lượng | Lượng bằng 6 Hòm Ngân Lượng cho nhân vật đang chơi, tăng theo cấp và số lần chuyển sinh. Mở từ cấp 80 hoặc sau chuyển sinh. Mua bao nhiêu lần cũng được. | Lượng bằng 6 Hòm Ngân Lượng |
| en | Gold Hoard | Gold worth 6 Gold Chests for the current hero, growing with level and rebirths. From level 80 or after a rebirth. Buy as often as you like. | Gold worth 6 Gold Chests |
| zh-TW | 銀兩大箱 | 為目前角色提供 6 個銀兩寶箱的銀兩，隨等級與轉生次數提高。80 級或轉生後開放，可重複購買。 | 等於 6 個銀兩寶箱 |
| ko | 냥 큰 상자 | 현재 캐릭터에게 냥 상자 6개 분량의 냥을 지급하며, 레벨과 환생 횟수에 따라 증가합니다. 80레벨 또는 환생 후 개방, 반복 구매 가능. | 냥 상자 6개 분량의 냥 |

## kh_kho_ngan_luong

Tiêu hao (Consumable) · 399.000 ₫

| | Tên | Mô tả (Play) | Mô tả (App Store) |
|---|---|---|---|
| vi | Kho Ngân Lượng | Giá tốt nhất: lượng bằng 15 Hòm Ngân Lượng cho nhân vật đang chơi, tặng 30 Tinh Thạch. Tăng theo cấp và chuyển sinh. Mở từ cấp 80 hoặc sau chuyển sinh. | 15 Hòm Ngân Lượng + 30 Tinh Thạch |
| en | Gold Vault | Best value: gold worth 15 Gold Chests for the current hero, plus 30 Star Stones. Grows with level and rebirths. From level 80 or after a rebirth. | 15 Gold Chests of gold + 30 Star Stones |
| zh-TW | 銀兩寶庫 | 最划算：為目前角色提供 15 個銀兩寶箱的銀兩，加贈 30 星石。隨等級與轉生提高，80 級或轉生後開放。 | 15 個銀兩寶箱 + 30 星石 |
| ko | 냥 보물고 | 최고 가성비: 현재 캐릭터에게 냥 상자 15개 분량의 냥과 성석 30개 지급. 레벨과 환생에 따라 증가, 80레벨 또는 환생 후 개방. | 냥 상자 15개 분량 + 성석 30개 |
