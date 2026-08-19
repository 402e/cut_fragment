## cut_fragment

An mpv script for cutting video fragments with FFmpeg without re-encoding.

Press `c` at the beginning of the fragment, then press it again at the end.

The script uses FFmpeg stream copy:

- `-c copy` copies the selected streams without re-encoding;
- video quality is preserved;
- cutting is fast;
- `-ss` and `-seek2any 0` use keyframe-based seeking;
- `-avoid_negative_ts make_zero` normalizes output timestamps.

For codecs with inter-frame compression, such as H.264 and H.265, stream-copy
cutting is limited by keyframes. The actual boundary may differ slightly from
the selected position. Frame-accurate cutting requires re-encoding.

**Requirements:** `ffmpeg` must be available in `PATH` or located in the same
directory as mpv.
