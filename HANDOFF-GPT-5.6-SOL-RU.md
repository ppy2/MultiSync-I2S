# Handoff для GPT-5.6-sol: RV1106 MultiSync first-SDATA desync

Ты продолжаешь расследование intermittent physical raw-SDATA false-start в трёхузловой RV1106 I2S системе. Отвечай и работай по-русски, кратко и фактически. Не объявляй workaround root-cause fix. Не меняй live nodes без explicit deploy request, кроме прямой команды пользователя «делай/записывай».

## Узлы и текущий режим

```text
master   10.10.10.192
slave-2  10.10.10.124
slave    10.10.10.181

текущий проблемный тест:
352800 Hz PCM, S32, NAA log: start 352800/32/4 [pcm]
MCLK = 45.1584 MHz
BCLK = 22.5792 MHz
master_start_delay_ms = 500
postmute_delay_ms = 1
```

Пользователь не интересуется 176.4 kHz как target test; фокус — 352.8 kHz.

## Требование / физика

```text
Общие физически соединённые nets:
MCLK, BCLK, LRCK, C7(GPIO1_C7), C6(GPIO1_C6)

Независимые сигналы:
master SDATA, slave-2 SDATA, slave SDATA
```

На разной ноде должна быть разная filter/band PCM DATA — копировать master SDATA на slaves нельзя.

Acceptance criterion: logic analyzer first raw SDATA, не dmesg/DMA/pointers/system clock.

## Симптом

На seek/start внутри non-silent track early raw SDATA мигрирует между:

```text
master / slave-2 / slave
```

Правильных стартов большинство. Это доказывает, что architecture может синхронизироваться; проблема intermittent/state-dependent, не фундаментальная невозможность.

## Уже подтверждено и НЕ повторять без нового основания

1. C7 physical path не является +hundreds-ms root cause.
   - C6 diagnostic image: master pulse immediately after C7 write; slave pulse first action of C7 IRQ.
   - Analyzer видел только C6 pulse около C7; separate +624 ms pulse не было.
   - C7/IRQ physical overlap подтверждён.
   - Старые cross-node dmesg offset claims нельзя считать physical timing evidence.

2. NAA lifecycle не показал error.
   - `/tmp/log` создан через live `/etc/init.d/S95naa` redirect stdout/stderr.
   - Нормальные lines: `start ...`, `waiting for trigger`, `engine running`, normal stop/drop.
   - Не менять версию networkaudiod.
   - NAA запускается с `LD_PRELOAD=/usr/lib/libasound_nodrain.so`; не предлагать blind snd_pcm_close/drain.

3. Normal STOP I2S_CLR действительно очищает controller-visible FIFO.
   Current diagnostic `I2S_STOP_READBACK` immediately after actual `I2S_CLR` showed on master and both slaves:

```text
clear=0 req=00000003 XFER=00000000 FIFOLR=00000000 INTSR=00000000 CLR=00000000
```

   Master early SDATA всё равно был пойман в той же test series.
   Следовательно normal FIFO residue after CLR не является explanation для master early.

4. `failed to clear 3` real, но не sufficient cause of false-start.
   - `3 = I2S_CLR_TXC | I2S_CLR_RXC`.
   - late slave STOP after master BCLK off может дать impossible SCLK-domain clear.
   - A/B master BCLK hold removed failed-clear but не убрал physical false-start.
   - Не возвращать master 2.5s BCLK hold.

5. Sysfs HCLK+TX+RX reset:
   - API assert/deassert returns 0.
   - reset_control_status returns -524 (unsupported), not hardware confirmation.
   - after reset readback often `FIFOLR=0x7f..0x8d`, but before next TRIGGER_START FIFO becomes 0.
   - This is reset/readback behavior; do not call it proven stale FIFO data.
   - User reports onstop reset scripts currently more stable, so do not remove them casually.

6. BCLK phase A/B was tested and got worse.
   - Correct method was DTB `simple-audio-card,bitclock-inversion;`, not a driver force override.
   - phase-inverted DTBs worsened behavior.
   - DTB source phase change reverted by commit `c97774f8`.
   - Do not retry CKP inversion without a materially new hypothesis.

7. C6 barrier/READY protocol permanently rejected.
   - FIFO/C6 barrier caused hang/global DATA blackout.
   - C6 marker was only diagnostic and should remain high-Z in baseline.

8. C7-start TX/RX reset, post-stop reset, clear-failure recovery at next start, double reset, userspace start reset, DMA-stop-before-clear, slave-only clear, and BCLK hold were negative/unsafe or insufficient experiments. Do not repeat blindly.

## Current scripts / rootfs state

Live hooks were standardized:

```text
master onstart:
  sleep 0.3
  exit 0

slave onstart:
  chronyc makestep
  chronyc burst 4/4
  chronyc waitsync 3 0.001 || true
  chronyc makestep
  exit 0

all onstop:
  sleep 0.2
  echo 1 > /sys/devices/platform/ffae0000.i2s/tx_reset
  sleep 0.3
  exit 0
```

Important correction: a mistaken daemon-restart recovery feature was created then fully removed. It must stay removed:

```text
no /opt/multisync-resync.sh
no recovery SSH key
no forced-command authorized_keys entries
commit removing it: b105f9e4
```

A user-triggered workaround, if desired, must mean normal HQPlayer playback stop/start or another seek while NAA remains running — NOT restart networkaudiod.

`/tmp/log` captures NAA stdout/stderr via S95naa. It is tmpfs and disappears on reboot.

## Current source / artifacts / deployment caveat

Repository:

```text
/opt/MultiSync-I2S
branch: master
```

Relevant commits:

```text
ef4b46a0 stable hooks
 e1e580fd sysfs reset readback diagnostic
 97576ba5 I2S_STOP_READBACK diagnostic
 0e8b549d phase inversion experiment (superseded)
 c97774f8 source revert to normal BCLK phase
 b105f9e4 remove mistaken daemon-restart recovery workaround
```

Last intended normal-phase boot artifacts written after phase rollback:

```text
master artifact:
plain-c7-stop-readback-master.img
SHA256 36309050e09e01857946d451b421bf044490de6e403ef4ae04ff3b0e61cf05d0

slaves artifact:
plain-c7-stop-readback-slave.img
SHA256 2e1fcff7fa4cb59090f5197179a55c402d06c48fc303a586aeb2f13cc66dc517
```

However, latest read-only check showed current `/dev/mtd3` hashes differ:

```text
master  0d1f41e4be8aa4260b1640cea34e64f325228d1c50e62da765bac460240ad79b
slaves  8a9ae0fcb7df1fcd3c67a4d74491bc5f6f7d45c8f629f991a79a855f0c0d5a50
```

Likely cause: reboot/configure workflow rewrote the role DTB region from `/data/boot`. Never assume mtd3 flash hash means the intended active DTB. Before any new deployment:

```text
1. hostname/IP preflight
2. inspect current live DTB /proc device tree or decompile live FDT
3. inspect /data/boot and /opt/configure.sh DTB selection
4. preserve/update role DTB files under /data/boot if necessary
5. separate compiled/written/readback/rebooted claims
```

Never write mtd4. Only mtd3, preserve role DTB, stop S95naa, verify zero NAA, erase/write/readback/cmp, restart NAA. Never automatically reboot.

## Current unresolved technical question

C7/IRQ, normal I2S_CLR FIFO clear, and normal NAA lifecycle are now excluded as sufficient explanations. The remaining physical boundary is:

```text
I2S serializer internal phase/state
→ SDATA pad/output visibility/release
```

Potential physical MCLK/BCLK input edge-quality/phase hypothesis remains unproven. Current logic analyzer max 100 MS/s is inadequate:

```text
MCLK 45.1584 MHz ≈ 2.21 samples/period
BCLK 22.5792 MHz ≈ 4.43 samples/period
```

Do not infer BCLK/MCLK edge phase from that analyzer. Need scope/high-speed probe or carefully designed high-speed divider if pursuing this hypothesis.

## Next agent rules

- Do not claim solution/guarantee.
- Do not repeat negative reset/C6/barrier/BCLK-phase experiments.
- Do not restart networkaudiod as a workaround.
- Preserve HQPlayer/NAA TCP transport port 43210 and installed NAA version.
- Use analyzer raw SDATA as acceptance.
- For each change: source patch → clean Buildroot patch/rebuild → verify compiled DTB/image → role-specific mtd3 write/readback → state reboot separately.
- First task: establish actual current active DTB and whether phase-inverted or normal DTB is running, because mtd3 changed after earlier rollback.
- Then propose one narrow next experiment aimed at serializer/pad, not another arbitrary delay.
