/*
 * ALSA drain wrapper for slave node
 * Converts snd_pcm_drain() to snd_pcm_drop() to avoid 10-second timeout
 * when master stops providing clocks
 *
 * Compile: gcc -shared -fPIC -o libasound_nodrain.so alsa_nodrain.c -ldl
 * Usage: LD_PRELOAD=/path/to/libasound_nodrain.so networkaudiod
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <alsa/asoundlib.h>

typedef int (*snd_pcm_drain_fn)(snd_pcm_t *pcm);
typedef int (*snd_pcm_drop_fn)(snd_pcm_t *pcm);

static snd_pcm_drain_fn real_drain = NULL;
static snd_pcm_drop_fn real_drop = NULL;

/* Initialize function pointers */
static void init_functions(void) {
    if (!real_drain) {
        real_drain = (snd_pcm_drain_fn)dlsym(RTLD_NEXT, "snd_pcm_drain");
        if (!real_drain) {
            fprintf(stderr, "alsa_nodrain: Failed to find snd_pcm_drain\n");
        }
    }
    if (!real_drop) {
        real_drop = (snd_pcm_drop_fn)dlsym(RTLD_NEXT, "snd_pcm_drop");
        if (!real_drop) {
            fprintf(stderr, "alsa_nodrain: Failed to find snd_pcm_drop\n");
        }
    }
}

/* Intercept snd_pcm_drain and convert to drop */
int snd_pcm_drain(snd_pcm_t *pcm) {
    init_functions();

    if (!real_drop) {
        /* Fallback to real drain if we can't find drop */
        return real_drain ? real_drain(pcm) : -1;
    }

    /* Convert drain to drop - immediate stop, no waiting */
    fprintf(stderr, "alsa_nodrain: Converting drain to drop (avoiding 10s timeout)\n");
    return real_drop(pcm);
}
