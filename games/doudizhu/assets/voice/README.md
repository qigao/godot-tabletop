# Example speech

Local demonstration speech generated with eSpeak NG 1.51, Mandarin (`cmn`), speed 160. Replace these WAVs through `media.tres` for final game narration. The runtime does not use a speech generator.

| Clip | Text |
| --- | --- |
| bid-0.wav | 不叫 |
| bid-1.wav | 一分 |
| bid-2.wav | 二分 |
| bid-3.wav | 三分 |
| pass.wav | 不出 |
| finished.wav | 本局结束 |
| bomb.wav | 炸弹 |
| rocket.wav | 王炸 |

Generation command, with the local eSpeak data parent supplied explicitly:

```sh
espeak-ng --path=/path/containing/espeak-ng-data -v cmn -s 160 -w bid-3.wav '三分'
```

The synthesizer executable and voice data are not distributed with the client. No external game recordings were copied. These clips demonstrate event mapping; physical speaker quality and final narration remain product acceptance.
