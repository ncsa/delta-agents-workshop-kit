/* pi_serial.c: pi as the midpoint-rule integral of 4/(1+x^2) over [0,1], one core.
 *
 *   build/pi_serial [N]      N intervals (default 1e9; "1e9" and "1000000000" both work)
 *
 * Prints the log protocol lines (topics/LOG-PROTOCOL.md):
 *   PROGRAM: pi_serial N: <N>
 *   RESULT: <pi> TIME: <seconds of the loop> WORKERS: 1
 */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + 1e-9 * (double)t.tv_nsec;
}

int main(int argc, char **argv)
{
    long long n = argc > 1 ? (long long)strtod(argv[1], NULL) : 1000000000LL;
    if (n < 1) {
        fprintf(stderr, "usage: %s [N > 0]\n", argv[0]);
        return 1;
    }
    double h = 1.0 / (double)n, sum = 0.0;
    double t0 = now();
    for (long long i = 0; i < n; i++) {
        double x = h * ((double)i + 0.5);
        sum += 4.0 / (1.0 + x * x);
    }
    double pi = h * sum;
    double t = now() - t0;
    printf("PROGRAM: pi_serial N: %lld\n", n);
    printf("RESULT: %.15f TIME: %.4f WORKERS: %d\n", pi, t, 1);
    fflush(stdout);
    return 0;
}
