#!/bin/bash
# Builds the promo videos from the captured clips: a clean 16:9 master, then
# a 16:9 version with captions and a 9:16 version for TikTok/Reels/Shorts.
set -e
cd "$(dirname "$0")"
FF=../ffmpeg/ffmpeg-n8.1-latest-win64-gpl-8.1/bin/ffmpeg.exe
MUSIC=/c/Users/Hi/.gemini/antigravity/scratch/kiem-hiep-app/assets/audio/music/battle.ogg
ENC="-r 30 -c:v libx264 -crf 17 -preset medium -pix_fmt yuv420p -an"
mkdir -p seg out
q() { "$FF" -hide_banner -loglevel error -y "$@"; }

# Gameplay segments.
q -ss 0 -t 5.5 -i clips/a_hoason.mp4 $ENC seg/1.mp4
q -ss 0 -t 4.5 -i clips/b_palm.mp4 $ENC seg/2.mp4
q -ss 2.0 -t 4.5 -i clips/d_swords.mp4 $ENC seg/3.mp4
q -ss 0.5 -t 5.5 -i clips/c_tower.mp4 $ENC seg/4.mp4

# Feature screens, 1.3 s each with a slow push-in.
for i in 1 2 3 4; do
  q -loop 1 -framerate 30 -t 1.3 -i stills/$i.png -vf \
    "scale=1920:1080,zoompan=z='1+0.035*on/39':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30" \
    $ENC seg/s$i.mp4
done

# End card over a blurred battle frame.
q -ss 3.0 -i clips/a_hoason.mp4 -frames:v 1 seg/bg.png
q -loop 1 -framerate 30 -t 3.5 -i seg/bg.png -i icon.png -filter_complex "\
[0]scale=1920:1080,boxblur=18:3,eq=brightness=-0.28[b];\
[1]scale=230:230[i];\
[b][i]overlay=(W-w)/2:120[bi];\
[bi]drawtext=fontfile=fonts/PlayfairDisplay.ttf:textfile=txt/title.txt:fontsize=124:fontcolor=0xF3D27A:\
borderw=5:bordercolor=0x2A1810:x=(w-text_w)/2:y=400,\
drawtext=fontfile=fonts/BeVietnamPro-Bold.ttf:textfile=txt/sub.txt:fontsize=56:fontcolor=0xF3E6C8:\
borderw=3:bordercolor=0x2A1810:x=(w-text_w)/2:y=575,\
drawtext=fontfile=fonts/BeVietnamPro-ExtraBold.ttf:textfile=txt/cta.txt:fontsize=58:fontcolor=white:\
box=1:boxcolor=0xA3271F:boxborderw=28:x=(w-text_w)/2:y=750,\
fade=t=in:st=0:d=0.35" $ENC seg/end.mp4

# Clean master (no captions).
q -i seg/1.mp4 -i seg/2.mp4 -i seg/3.mp4 -i seg/4.mp4 -i seg/s1.mp4 -i seg/s2.mp4 -i seg/s3.mp4 -i seg/s4.mp4 -i seg/end.mp4 \
  -filter_complex "[0][1][2][3][4][5][6][7][8]concat=n=9:v=1:a=0" $ENC seg/master.mp4

DUR=28.7
AUDIO="[1:a]atrim=0:$DUR,afade=t=in:st=0:d=0.3,afade=t=out:st=$(echo "$DUR - 2" | bc 2>/dev/null || echo 26.7):d=2[a]"

# Captions: text file, start, end.
caps=(
  "c1 0 5.5" "c2 5.5 10" "c3 10 14.5" "c4 14.5 20"
  "c5 20 21.3" "c6 21.3 22.6" "c7 22.6 23.9" "c8 23.9 25.2"
)
captions() { # fontsize y
  local out="" sep=""
  for c in "${caps[@]}"; do
    set -- $c
    out+="${sep}drawtext=fontfile=fonts/BeVietnamPro-ExtraBold.ttf:textfile=txt/$1.txt:fontsize=$FS:fontcolor=white:\
borderw=7:bordercolor=0x1A0E0A:shadowcolor=black@0.5:shadowx=4:shadowy=4:x=(w-text_w)/2:y=$CY:\
enable='between(t,$2,$3)':alpha='if(lt(t-$2,0.25),(t-$2)/0.25,1)'"
    sep=","
  done
  echo "$out"
}

# 16:9 with captions under the top HUD.
FS=78 CY=130
q -i seg/master.mp4 -stream_loop 1 -i "$MUSIC" -filter_complex "[0]$(captions)[v];$AUDIO" \
  -map "[v]" -map "[a]" -t $DUR -r 30 -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 160k -movflags +faststart out/kiem-hiep-promo-16x9.mp4

# 9:16: blurred fill behind the landscape video, title above, captions and
# the call to action around it (clear of TikTok's top bar and bottom UI).
FS=74 CY=470
q -i seg/master.mp4 -stream_loop 1 -i "$MUSIC" -filter_complex "\
[0]split[x][y];\
[x]scale=-2:1920,crop=1080:1920,boxblur=26:4,eq=brightness=-0.22[bg];\
[y]scale=1080:-2[fg];\
[bg][fg]overlay=0:(H-h)/2,\
drawtext=fontfile=fonts/PlayfairDisplay.ttf:textfile=txt/title.txt:fontsize=100:fontcolor=0xF3D27A:\
borderw=5:bordercolor=0x2A1810:x=(w-text_w)/2:y=250:enable='lt(t,25.2)',\
$(captions),\
drawtext=fontfile=fonts/BeVietnamPro-ExtraBold.ttf:textfile=txt/cta.txt:fontsize=50:fontcolor=white:\
box=1:boxcolor=0xA3271F:boxborderw=24:x=(w-text_w)/2:y=1360[v];$AUDIO" \
  -map "[v]" -map "[a]" -t $DUR -r 30 -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 160k -movflags +faststart out/kiem-hiep-promo-9x16.mp4

ls -la out
