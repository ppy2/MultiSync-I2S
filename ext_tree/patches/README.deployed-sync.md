# Active RV1106 kernel patch profile

The deployed SBC profile is Linux 5.10.160 from `ppy2/ale-linux-rv1106`.

The active baseline is Hermes session `20260821_095930_f35704`, accepted after
the corresponding firmware booted on the test SBC. This session supersedes the
older pre-arm-only baseline for reproducible builds.

Buildroot applies exactly these patches, in this order:

1. `linux_rv1106.patch`
2. `linux_rv1106_deployed_sync.patch`

`linux_rv1106_deployed_sync.patch` is the consolidated delta recovered from the
running SBC profile. It includes the active C7 sync path, generation-safe master
commit, quiet hot path, C6 high-Z behavior, RV1106 reset support, pre-start and
post-stop reset controls, DMA-before-clear ordering, and runtime master BCLK
hold.

The following snapshot/diagnostic patches remain in this directory as historical
provenance but are intentionally not listed in `BR2_LINUX_KERNEL_PATCH`:

- `linux_rv1106_fifo_arm.patch`
- `linux_rv1106_c6_c7_irq_marker.patch`
- `linux_rv1106_*_trace.patch`
- `linux_rv1106_*_readback.patch`
- `linux_rv1106_*_settle_200ms.patch`
- `linux_rv1106_c7_one_txrx_reset.patch`
- `linux_rv1106_c7_immediate_master_xfer.patch`

The live image did not contain the `FIFO_READY`, `DMA_FIRST_PERIOD`, reset
readback, or C7 TX/RX experimental markers. Do not append these patches to the
active series without a new device-level validation.
