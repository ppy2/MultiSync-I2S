/*
 * sync_node - Lightweight I2S sync daemon for shared-clock multi-node audio
 *
 * Master: UDP responder — reports its frame_counter to any slave.
 * Slave:  Queries master, measures clock drift using GROWING WINDOW.
 *         First correction after 10 minutes (noise < 5000 ppb, signal ~673 ppb).
 *         Updates every 5 minutes after that. Very conservative.
 *
 * Usage:
 *   sync_node master                   # Run on master: UDP responder
 *   sync_node slave <master_ip>        # Run on slave: monitor only
 *   sync_node slave <master_ip> -a     # Run on slave: auto-correct
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <time.h>

#define PORT 7654
#define SYSFS "/sys/devices/platform/ffae0000.i2s"
#define POLL_S 10               /* measurement every 10s */
#define FIRST_APPLY_S 600       /* first correction after 10 min */
#define UPDATE_S 300            /* re-evaluate every 5 min */
#define MAX_SANE_PPB 20000      /* sanity: max 20 ppm */

static volatile int running = 1;

static void sig_handler(int sig) { (void)sig; running = 0; }

static int read_frame_counter(unsigned long long *frames, long long *elapsed_us,
                              unsigned int *rate)
{
    FILE *f = fopen(SYSFS "/frame_counter", "r");
    if (!f) return -1;
    int r = fscanf(f, "%llu %lld %u", frames, elapsed_us, rate);
    fclose(f);
    return (r == 3) ? 0 : -1;
}

static long long read_drift_ppb(void)
{
    FILE *f = fopen(SYSFS "/drift_ppb", "r");
    if (!f) return 0;
    long long val = 0;
    fscanf(f, "%lld", &val);
    fclose(f);
    return val;
}

static int write_drift_ppb(long long val)
{
    FILE *f = fopen(SYSFS "/drift_ppb", "w");
    if (!f) return -1;
    fprintf(f, "%lld\n", val);
    fclose(f);
    return 0;
}

/* ========== MASTER MODE ========== */
static int run_master(void)
{
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { perror("socket"); return 1; }

    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port = htons(PORT),
        .sin_addr.s_addr = INADDR_ANY
    };

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(sock); return 1;
    }

    printf("sync_node master: listening on UDP port %d\n", PORT);

    char buf[256];
    struct sockaddr_in client;
    socklen_t clen;

    while (running) {
        clen = sizeof(client);
        int n = recvfrom(sock, buf, sizeof(buf) - 1, 0,
                         (struct sockaddr *)&client, &clen);
        if (n <= 0) continue;
        buf[n] = '\0';

        if (buf[0] == 'Q') {
            unsigned long long frames;
            long long elapsed_us;
            unsigned int rate;

            if (read_frame_counter(&frames, &elapsed_us, &rate) == 0) {
                int len = snprintf(buf, sizeof(buf), "F %llu %lld %u\n",
                                   frames, elapsed_us, rate);
                sendto(sock, buf, len, 0,
                       (struct sockaddr *)&client, clen);
            } else {
                sendto(sock, "E no_playback\n", 14, 0,
                       (struct sockaddr *)&client, clen);
            }
        }
    }

    close(sock);
    return 0;
}

/* ========== SLAVE MODE ========== */

static int query_master(int sock, struct sockaddr_in *master_addr,
                        unsigned long long *frames, long long *elapsed_us,
                        unsigned int *rate)
{
    char buf[256];
    struct sockaddr_in from;
    socklen_t flen = sizeof(from);

    sendto(sock, "Q", 1, 0, (struct sockaddr *)master_addr,
           sizeof(*master_addr));

    struct timeval tv = { .tv_sec = 2, .tv_usec = 0 };
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    int n = recvfrom(sock, buf, sizeof(buf) - 1, 0,
                     (struct sockaddr *)&from, &flen);
    if (n <= 0) return -1;
    buf[n] = '\0';

    if (buf[0] != 'F') return -1;
    return (sscanf(buf + 1, "%llu %lld %u",
                   frames, elapsed_us, rate) == 3) ? 0 : -1;
}

static int run_slave(const char *master_ip, int auto_correct)
{
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { perror("socket"); return 1; }

    struct sockaddr_in master_addr = {
        .sin_family = AF_INET,
        .sin_port = htons(PORT)
    };
    inet_pton(AF_INET, master_ip, &master_addr.sin_addr);

    printf("sync_node slave: master=%s auto=%s (growing window)\n",
           master_ip, auto_correct ? "ON" : "OFF");
    printf("  First correction after %ds, then every %ds\n",
           FIRST_APPLY_S, UPDATE_S);
    printf("%-7s %-12s %-12s %-10s %-10s %-8s %s\n",
           "TIME", "M_RATE", "MY_RATE", "DRIFT_PPB", "EST_NOISE", "CUR_PPB", "STATUS");

    /* Anchor */
    unsigned long long anc_m_frames = 0, anc_my_frames = 0;
    long long anc_m_us = 0, anc_my_us = 0;
    int have_anchor = 0;

    long long last_apply_s = 0;
    int applied_count = 0;

    while (running) {
        unsigned long long m_frames, my_frames;
        long long m_us, my_us;
        unsigned int m_rate, my_rate;

        if (read_frame_counter(&my_frames, &my_us, &my_rate) != 0) {
            printf("\rWaiting for local playback...");
            fflush(stdout);
            have_anchor = 0;
            sleep(POLL_S);
            continue;
        }

        if (query_master(sock, &master_addr, &m_frames, &m_us, &m_rate) != 0) {
            printf("\rMaster unreachable...");
            fflush(stdout);
            have_anchor = 0;
            sleep(POLL_S);
            continue;
        }

        if (m_rate == 0 || my_rate == 0) {
            printf("\rWaiting for playback...");
            fflush(stdout);
            have_anchor = 0;
            sleep(POLL_S);
            continue;
        }

        if (!have_anchor) {
            anc_m_frames = m_frames;
            anc_m_us = m_us;
            anc_my_frames = my_frames;
            anc_my_us = my_us;
            have_anchor = 1;
            last_apply_s = 0;
            applied_count = 0;
            printf("  anchor set, accumulating...\n");
            sleep(POLL_S);
            continue;
        }

        /* Growing window from anchor */
        long long dm_frames = (long long)(m_frames - anc_m_frames);
        long long dm_us = m_us - anc_m_us;
        long long dmy_frames = (long long)(my_frames - anc_my_frames);
        long long dmy_us = my_us - anc_my_us;

        if (dm_us <= 0 || dmy_us <= 0 || dm_frames <= 0 || dmy_frames <= 0) {
            printf("  counter reset, re-anchoring...\n");
            have_anchor = 0;
            sleep(POLL_S);
            continue;
        }

        double m_eff = (double)dm_frames / (double)dm_us * 1e6;
        double my_eff = (double)dmy_frames / (double)dmy_us * 1e6;
        double nominal = (double)m_rate;
        long long drift_ppb = (long long)((m_eff - my_eff) / nominal * 1e9);

        double elapsed_s = (double)dmy_us / 1e6;
        double est_noise = 2.0 * 5461.0 / (nominal * elapsed_s) * 1e9;

        long long cur_ppb = read_drift_ppb();
        const char *status = "accumulating";

        if (elapsed_s >= FIRST_APPLY_S) {
            long long since_apply = (long long)elapsed_s - last_apply_s;

            if (auto_correct &&
                (applied_count == 0 || since_apply >= UPDATE_S)) {

                if (drift_ppb > -MAX_SANE_PPB && drift_ppb < MAX_SANE_PPB) {
                    if (write_drift_ppb(drift_ppb) == 0) {
                        cur_ppb = drift_ppb;
                        status = ">>> APPLIED <<<";
                        last_apply_s = (long long)elapsed_s;
                        applied_count++;
                    } else {
                        status = "WRITE_ERR";
                    }
                } else {
                    status = "INSANE";
                }
            } else {
                status = "ready";
            }
        }

        int mins = (int)(elapsed_s / 60);
        int secs = (int)(elapsed_s) % 60;
        printf("%3dm%02ds %-12.3f %-12.3f %-10lld %-10.0f %-8lld %s\n",
               mins, secs, m_eff, my_eff, drift_ppb, est_noise, cur_ppb, status);

        if (((int)elapsed_s) % 60 < POLL_S && elapsed_s > 30) {
            double ms_hr = ((double)drift_ppb / 1e9) * 3600.0 * 1000.0;
            printf("  >>> drift=%lld ppb (%.2f ms/hr) noise=%.0f ppb corrections=%d\n",
                   drift_ppb, ms_hr, est_noise, applied_count);
        }

        sleep(POLL_S);
    }

    close(sock);
    return 0;
}

int main(int argc, char *argv[])
{
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    if (argc < 2) goto usage;

    if (strcmp(argv[1], "master") == 0 || strcmp(argv[1], "m") == 0)
        return run_master();

    if (strcmp(argv[1], "slave") == 0 || strcmp(argv[1], "s") == 0) {
        if (argc < 3) goto usage;
        int auto_correct = (argc >= 4 && strcmp(argv[3], "-a") == 0);
        return run_slave(argv[2], auto_correct);
    }

usage:
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  %s master               - UDP responder (run on master)\n", argv[0]);
    fprintf(stderr, "  %s slave <master_ip> [-a] - Monitor/correct (run on each slave)\n", argv[0]);
    return 1;
}
