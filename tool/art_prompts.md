# Prompt ChatGPT – đợt đồ họa tiếp theo

Cách dùng: mỗi khối là **một ảnh**. Dán nguyên prompt vào ChatGPT, tải PNG về,
đổi tên đúng như dòng **Lưu thành**, bỏ vào `art_in/`. Ảnh nào hỏng thì bảo
ChatGPT "vẽ lại, giữ nguyên phong cách" thay vì viết prompt mới.

Mẹo giữ đồng bộ phong cách: trong cùng một cuộc chat ChatGPT, **gửi kèm 1 tấm
icon cũ** (ví dụ `art_in/consumables.png`) ở tấm đầu tiên và nói
"match this style exactly" — các tấm sau trong cùng chat sẽ theo.

Phong cách chung (đã có trong từng prompt, ghi ra để dễ sửa):

> STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark
> brown outline, glossy rich colours, soft inner highlights, gold filigree
> accents, small red Chinese knot with tassel as a recurring motif, slight
> 3/4 view, no text, no letters, no numbers, transparent background, icons
> spaced well apart and NOT touching or overlapping, no glow that joins two
> icons.

---

## 1. Icon các ô chức năng ở thành (ưu tiên cao nhất)

5 tấm, ngang, nền trong suốt. Mỗi icon khoảng vuông, cỡ đều nhau.

### 1a – Lưu thành `town_1.png`
```
A horizontal row of 5 separate game icons, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark brown outline, glossy rich colours, soft inner highlights, gold filigree accents, small red Chinese knot with tassel as a recurring motif, slight 3/4 view, no text, no letters, no numbers, icons NOT touching, no glow joining them.
Left to right:
1. MAP – an unrolled ancient parchment map with ink-painted mountains and a river, wooden scroll rods with gold caps.
2. DUNGEON – a dark stone cave gate carved like a demon mouth, faint red light inside, two small torches.
3. CHALLENGE – two crossed swords over a burning flame emblem, sparks.
4. QUESTS – a bamboo-slip scroll (zhujian) tied with red string, a brush resting on it.
5. HERO – a bronze wuxia warrior bust medallion: a round gold-rimmed plaque with the silhouette of a swordsman with topknot.
```

### 1b – Lưu thành `town_2.png`
```
A horizontal row of 5 separate game icons, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark brown outline, glossy rich colours, soft inner highlights, gold filigree accents, small red Chinese knot with tassel as a recurring motif, slight 3/4 view, no text, no letters, no numbers, icons NOT touching, no glow joining them.
Left to right:
1. MANOR – a small elegant Chinese courtyard house with curved grey-tile roof and a red door, a pine tree beside it.
2. COMPANIONS – two small chibi wuxia figures standing back to back (a swordsman in blue and a lady in pink), inside a round gold frame.
3. LEADERBOARD – a three-step jade and gold podium with a small gold crown on the top step.
4. GUILD – a heraldic war banner on a pole, dark red cloth with a gold dragon motif, fluttering.
5. ALCHEMY – a three-legged bronze cauldron (ding) with green-blue smoke and a few glowing pills.
```

### 1c – Lưu thành `town_3.png`
```
A horizontal row of 5 separate game icons, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark brown outline, glossy rich colours, soft inner highlights, gold filigree accents, small red Chinese knot with tassel as a recurring motif, slight 3/4 view, no text, no letters, no numbers, icons NOT touching, no glow joining them.
Left to right:
1. DAILY ACTIVITY – a red lacquer treasure chest with gold corners, a small flame rising from its lid.
2. SECT – a mountain temple gate (paifang) with a curved roof on a cliff, clouds below.
3. SHOP – a merchant stall: a cloth awning over a wooden counter with a gold ingot, a pouch and a vase.
4. FORGE – a blacksmith hammer striking a glowing red-hot sword blade on an anvil, sparks.
5. ACHIEVEMENTS – a gold trophy cup in Chinese style with dragon handles and a jade inlay.
```

### 1d – Lưu thành `town_4.png`
```
A horizontal row of 5 separate game icons, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark brown outline, glossy rich colours, soft inner highlights, gold filigree accents, small red Chinese knot with tassel as a recurring motif, slight 3/4 view, no text, no letters, no numbers, icons NOT touching, no glow joining them.
Left to right:
1. DAILY GIFT – a red gift box wrapped with a gold ribbon and a red knot on top.
2. BAG – a brown leather travel pouch with drawstring, a sword hilt and a scroll sticking out.
3. GUIDE – a glowing paper lantern with a small light bulb-shaped flame inside (idea / hint).
4. NEWS – a wooden notice board on two posts with pinned paper notices and a small bell.
5. MAIL – a sealed letter envelope with a red wax seal, a white crane feather beside it.
```

### 1e – Lưu thành `town_5.png`
```
A horizontal row of 2 separate game icons, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark brown outline, glossy rich colours, soft inner highlights, gold filigree accents, small red Chinese knot with tassel as a recurring motif, slight 3/4 view, no text, no letters, no numbers, icons NOT touching, no glow joining them.
Left to right:
1. WORLD CHAT – a carrier pigeon in flight holding a small rolled message, speech-bubble-shaped cloud behind it.
2. FRIENDS – two wine cups clinking together over a small wine jar (brotherhood toast).
```

---

## 2. Nền đất trong trận (15 vùng)

Mỗi vùng **một ảnh vuông 1024×1024**. Quan trọng nhất là **lặp liền mạch**
và **nhìn thẳng từ trên xuống**, không có vật cao đổ bóng (cây, đá to, nhà do
game tự vẽ lên trên). Màu hơi trầm để nhân vật và quái nổi lên.

Khung prompt (thay phần `[...]`):
```
A seamless tileable ground texture, 1024x1024, viewed straight from above (top-down, orthographic), for a 2D action RPG battlefield. The edges must wrap perfectly in both directions with no visible seam. Painted game-art style matching a Chinese wuxia fantasy game, soft brush texture, medium detail. No objects that cast long shadows, no trees, no buildings, no characters, no text. Slightly muted, low contrast so characters stand out on top.
Ground: [MÔ TẢ]
```

| Lưu thành | Vùng | [MÔ TẢ] |
|---|---|---|
| `ground_grass.png` | Ngoại Thành Lạc An | lush green meadow grass with small patches of packed dirt and tiny white and blue wildflowers, a few pebbles |
| `ground_bamboo.png` | Tử Trúc Lâm | forest floor covered in fallen dry bamboo leaves, dark soil, moss, tiny violet bamboo shoots |
| `ground_cave.png` | Hắc Phong Động | dark damp cave rock floor, cracked slate, small puddles, faint teal glowing lichen |
| `ground_desert.png` | Hoàng Sa Mạc | golden desert sand with soft wind ripples, scattered small stones and dry twigs |
| `ground_snow.png` | Băng Tuyết Nguyên | packed snow with footprints-free soft drifts, patches of blue ice and frosted grass tufts |
| `ground_volcano.png` | Hỏa Diệm Sơn | dark volcanic basalt and ash with thin glowing orange lava cracks, scorched pebbles |
| `ground_fortress.png` | Ma Giáo Tổng Đàn | old dark stone paving slabs of a demonic sect courtyard, worn cracks, faint dried red stains, moss in joints |
| `ground_cloud.png` | Vân Vụ Sơn | pale mountain rock and short silvery grass with thin drifting mist wisps across the ground |
| `ground_summit.png` | Hoa Sơn Tuyệt Đỉnh | weathered granite mountain-top stone with pine needles and thin snow in cracks |
| `ground_abyss.png` | Cửu U Ma Vực | black-purple cursed earth with faint violet glowing runes cracks and bone fragments |
| `ground_sea.png` | Đông Hải Quần Đảo | wet beach sand with small shells, seaweed and shallow tide-pool patches |
| `ground_bloodSea.png` | U Minh Huyết Hải | dark crimson muddy shore with blood-red shallow puddles and black rocks |
| `ground_canyon.png` | Tây Vực Cổ Đạo | red-orange canyon clay with layered rock plates, dry cracked earth and sparse desert shrubs |
| `ground_jungle.png` | Miêu Cương Cổ Lâm | humid jungle floor with large fallen leaves, roots, dark mud and small poisonous-looking mushrooms |
| `ground_kunlun.png` | Côn Lôn Tiên Cảnh | white jade-like stone paving with pale cyan veins, fresh snow dusting and tiny glowing spirit flowers |

Nếu ảnh ra bị lộ đường nối: nói ChatGPT "make it truly seamless: the left
edge must continue the right edge and the top edge must continue the bottom
edge". Mình sẽ kiểm tra lại đường nối bằng script trước khi đưa vào game.

---

## 3. Huy hiệu hạng Lôi đài (7 bậc)

### 3a – Lưu thành `arena_1.png` (bậc 1–4)
```
A horizontal row of 4 separate rank emblems for a wuxia arena ladder, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG emblem, Chinese wuxia fantasy, thick dark brown outline, glossy, gold filigree, each emblem is a shield-shaped medal with a sword motif, each tier clearly richer and more ornate than the last, no text, no letters, no numbers, emblems NOT touching.
Left to right:
1. "Novice" – plain worn beige-grey stone medal with a simple wooden practice sword.
2. "Bronze" – copper-bronze medal (#C8844A) with one bronze sword and small laurel.
3. "Silver" – polished silver medal (#D8E0E8) with two crossed silver swords.
4. "Gold" – shining gold medal (#FFD34A) with two crossed gold swords and small wings.
```

### 3b – Lưu thành `arena_2.png` (bậc 5–7)
```
A horizontal row of 3 separate rank emblems for a wuxia arena ladder, evenly spaced, same size, on a transparent background, continuing the same series (match the previous emblem style exactly).
STYLE: polished painted mobile-RPG emblem, Chinese wuxia fantasy, thick dark brown outline, glossy, gold filigree, shield-shaped medal with sword motif, no text, no letters, no numbers, emblems NOT touching.
Left to right:
5. "Platinum" – pale cyan-white platinum medal (#9AE8E0) with crossed swords, small crystals and cloud wings.
6. "Grandmaster" – violet jade medal (#C8A0FF) with crossed swords, a gold crown and spreading phoenix wings.
7. "Supreme of the Martial World" – blazing red-orange and gold medal (#FF6A4A) with a coiled dragon around a sword, crown, flames, the most magnificent of all.
```

### 3c – Lưu thành `ranks.png` (xếp hạng + bang)
```
A horizontal row of 5 separate emblems, evenly spaced, same size, on a transparent background.
STYLE: polished painted mobile-RPG emblem, Chinese wuxia fantasy, thick dark brown outline, glossy, gold filigree, no text, no letters, no numbers, emblems NOT touching.
Left to right:
1. 1st place – round gold medal with a red ribbon and a small dragon relief.
2. 2nd place – round silver medal with a blue ribbon and a phoenix relief.
3. 3rd place – round bronze medal with a green ribbon and a tiger relief.
4. Guild emblem – a round banner crest with a red and gold dragon, two crossed spears behind.
5. Guild war – two war flags crossed over a small fortress tower, fire behind.
```

---

## 4. Khung giao diện (UI)

Lưu ý: ChatGPT hay vẽ khung lệch, mình sẽ cắt 9-slice nên cần **phần giữa
trơn, 4 góc trang trí, 4 cạnh lặp đều**. Màu nền app: gỗ sơn mài nâu đen
`#2A1C17`, vàng `#D9A93B`, kem `#F3E6C8`, đỏ triện `#A3271F`.

### 4a – Lưu thành `ui_panel.png`
```
A single rectangular UI panel frame for a mobile wuxia RPG, front view, perfectly symmetric, 1024x768, on a transparent background.
Dark brown-black lacquered wood board (#2A1C17) with a thin gold (#D9A93B) inner border line. Four ornate gold cloud-scroll corner pieces. The straight edges between corners must be plain and uniform (so they can be stretched). The centre must be flat, plain and empty with only a very subtle wood grain. No text, no icons, no shadows outside the frame.
```

### 4b – Lưu thành `ui_buttons.png`
```
A horizontal row of 3 separate empty game UI buttons, evenly spaced, same size, wide rounded-rectangle shape about 4:1, front view, perfectly symmetric, on a transparent background.
Painted mobile wuxia RPG style, thick dark brown outline, glossy lacquer, small gold end caps with cloud motif at the left and right ends, the middle stretch plain and uniform. No text.
Left to right:
1. Primary – red seal lacquer (#A3271F) with gold rim.
2. Secondary – dark brown lacquer (#3D2A22) with gold rim.
3. Disabled – dull grey-brown lacquer with dim bronze rim.
```

### 4c – Lưu thành `ui_slots.png`
```
A horizontal row of 5 separate empty square item-slot frames, evenly spaced, same size, front view, perfectly symmetric, on a transparent background.
Painted mobile wuxia RPG style: dark lacquer inner square (#170F0C), ornate frame with small corner ornaments; each frame tier more ornate than the last. The centre must be empty and flat. No text, no items inside.
Left to right by rarity colour:
1. Common – plain pale ivory frame (#E8E2D4).
2. Fine – blue enamel frame (#5AA9F0).
3. Precious – gold frame (#F0C24B) with small cloud corners.
4. Rare – purple jade frame (#B57BF0) with crystal corners.
5. Legendary – blazing orange-gold frame (#FF8A3D) with small dragon heads on the corners and a soft flame aura.
```

### 4d – Lưu thành `ui_title_bar.png`
```
A single horizontal title banner for a mobile wuxia RPG screen header, front view, perfectly symmetric, very wide (about 6:1), on a transparent background.
A horizontal unrolled scroll: cream paper (#F3E6C8) in the middle, dark wooden rollers with gold caps on both ends, a small red knot with tassel hanging from each roller. The middle paper area plain and empty for text. No text.
```

---

## 5. Sổ cá (36 loài, 9 tấm)

Mỗi tấm là 4 con cá của một vùng, xếp từ thường đến huyền thoại. Con huyền
thoại nên to và lấp lánh hơn hẳn.

Khung prompt (thay phần `[...]`):
```
A horizontal row of 4 separate fish icons, evenly spaced, each fish in side view facing left, on a transparent background.
STYLE: polished painted mobile-RPG icon, Chinese wuxia fantasy, thick dark brown outline, glossy rich colours, soft highlights, each fish more magical than the last (the 4th is legendary, with a faint aura and sparkles), no text, no letters, fish NOT touching, no glow joining them.
Left to right:
[4 DÒNG MÔ TẢ]
```

| Lưu thành | 4 dòng mô tả |
|---|---|
| `fish_ngoaithanh.png` | 1. Golden crucian carp, small and round. 2. Plump grass carp, olive green. 3. Pink carp with peach-blossom pink scales. 4. Legendary golden carp turning into a dragon: carp body with small dragon horns and whiskers, leaping, water splash. |
| `fish_truclam.png` | 1. Small brown climbing perch. 2. Catfish with long whiskers and bamboo-node stripes. 3. Translucent jade-green fish, see-through like glass. 4. Legendary king fish of the purple bamboo forest: violet scales, bamboo-leaf fins, small gold crown-like crest. |
| `fish_hacphong.png` | 1. Pale blind cave fish with no eyes. 2. Long eel glowing faint blue-green. 3. Black fish with crescent-moon shaped fins. 4. Legendary underground dragon fish: dark blue-black, long dragon whiskers, glowing cyan eyes. |
| `fish_hoangsa.png` | 1. Snakehead fish, sandy brown. 2. Fish with glittering gold-sand scales. 3. Fish with a red ruby gem set in its forehead. 4. Legendary desert god fish: sand-gold and turquoise, fins like silk banners, a tiny water drop halo. |
| `fish_bangnguyen.png` | 1. Ice salmon, silver-pink. 2. Pure white carp, frosty. 3. Fish carved from clear blue ice, faceted. 4. Legendary giant frost leviathan fish: huge, pale blue, ice spikes on its back, snowflakes around. |
| `fish_hoadiem.png` | 1. Dark fish with ember-orange glowing spots. 2. Fish with scales red like burning coals. 3. Fish with a fanned tail like phoenix feathers, red and gold. 4. Legendary fire dragon fish breathing a small flame, molten orange scales. |
| `fish_magiao.png` | 1. Murky moat fish, grey-green. 2. Dark crimson-scaled fish with sharp teeth. 3. Half-transparent ghostly shadow fish, purple-grey. 4. Legendary demon flood-dragon fish: black and blood red, horns, demonic purple aura. |
| `fish_vanvu.png` | 1. Fluffy pale fish like a little cloud. 2. Sky-blue carp. 3. Fish with a long crane-like beak, white and red crest. 4. Legendary white dragon fish: pearl white, long flowing fins, small dragon horns, cloud wisps. |
| `fish_hoason.png` | 1. Swordfish with a needle-sharp snout like a sword tip. 2. Fish with pine-needle shaped green fins swimming up a waterfall. 3. Silver fish with a faint blue sword-energy aura. 4. Legendary Hua Mountain god fish: silver and gold, fins shaped like crossed sword blades, a blue sword aura. |

---

## 6. Cá 4 vùng mới (1.26)

Cùng khung prompt với §5 (4 con một tấm, từ thường đến huyền thoại). Làm
trong **cùng cuộc chat** với các tấm cá trước, hoặc gửi kèm
`art_in/fish_ngoaithanh.png` và nói "match this style exactly".

| Lưu thành | 4 dòng mô tả |
|---|---|
| `fish_mieucuong.png` | 1. Small grey-green stream catfish with short whiskers, mossy spots. 2. Dark jungle fish with a tiny golden gu-insect glowing inside its translucent belly. 3. Iridescent rainbow fish whose scales shift through seven colours. 4. Legendary golden silkworm fish king: gold scales patterned like silkworm segments, venom-green fins, small crown crest, faint green aura. |
| `fish_tayvuc.png` | 1. Rust-red fish the colour of desert sandstone, rough scales. 2. Pale fish with white bones showing through thin translucent skin. 3. Fish with a flame-shaped dorsal fin in red and orange, like a small fire spirit. 4. Legendary glass fish: body clear as coloured glaze (blue-turquoise), golden fins like silk, water-drop halo. |
| `fish_donghai.png` | 1. Silver mackerel with blue-striped back. 2. Small squid glowing soft cyan-blue, curling tentacles. 3. Pink-white fish holding a shining pearl in its mouth. 4. Legendary dragon-palace guard fish: jade-green scales, small dragon horns and whiskers, trident-shaped tail, sea-foam swirl. |
| `fish_conlon.png` | 1. Small snow-white fish with pale blue fins, frosty sparkle. 2. Fish clear green like jade, gold-rimmed fins. 3. White-pink fish curled under a frosted lotus leaf. 4. Legendary Kunlun immortal fish: pearl white and pale gold, long flowing fins like clouds, riding a small cloud, soft halo. |

---

## 7. Boss Hoàng Kim hệ Mộc và Hỏa (1.28)

Mỗi khối là một ảnh chân dung toàn thân, cùng kiểu với `assets/art/gbSpear.webp`.
Gửi kèm `gbSpear.webp` (hoặc `gbLady.webp`) và nói "match this style exactly".
Đã có ảnh (2026-11-28). Bỏ PNG vào `art_in/`. Khi có ảnh, gỡ id khỏi `bossArtPending` và thêm vào
`bossArtIds` (lib/ui/world_boss_screen.dart).

### 7a – Lưu thành `gbWood.png`

> Full-body character painting, Chinese wuxia fantasy, polished painted
> mobile-RPG style, rich colours, fine gold filigree, standing in a dynamic
> 3/4 pose, transparent background, no text. An ancient forest demon elder,
> "Green Vine Elder Fiend": tall old man with long white hair and beard, deep
> green layered robe with brown bark-textured trim, a mossy dark-green cape,
> living vines and small leaves twining around his arms and shoulders, holding
> a gnarled wooden staff topped with a glowing pale-green jade bud, faint
> green spirit light and drifting leaves around him. Menacing, regal, boss
> presence.

### 7b – Lưu thành `gbFire.png`

> Full-body character painting, Chinese wuxia fantasy, polished painted
> mobile-RPG style, rich colours, fine gold filigree, standing in a dynamic
> 3/4 pose, transparent background, no text. A fire demon lord, "Crimson Flame
> Demon Lord": fierce man with a small gold crown on a black topknot, crimson
> lacquered armour with blackened-iron plates and amber-gold trim, a ragged
> charcoal-black cape with glowing ember edges, wielding a broad curved saber
> whose blade glows orange like molten metal, flame wisps and sparks swirling
> at his feet. Menacing, regal, boss presence.
