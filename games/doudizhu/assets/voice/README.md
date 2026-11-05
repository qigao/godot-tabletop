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

Additional interaction baseline clips:

| Clip | Text |
| --- | --- |
| single.wav | 单张 |
| pair.wav | 对子 |
| triple.wav | 三张 |
| triple_single.wav | 三带一 |
| triple_pair.wav | 三带二 |
| straight.wav | 顺子 |
| pair_straight.wav | 连对 |
| airplane.wav | 飞机 |
| airplane_single.wav | 飞机带单 |
| airplane_pair.wav | 飞机带对 |
| four_two_single.wav | 四带二 |
| four_two_pair.wav | 四带两对 |
| one-left.wav | 我还剩一张牌 |
| two-left.wav | 我还剩两张牌 |
