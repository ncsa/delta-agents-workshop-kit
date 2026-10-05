/* pi_omp.c: the pi_serial.c integral with OpenMP threads on one node.
 *
 *   OMP_NUM_THREADS=<t> build/pi_omp [N]
 *
 * The loop is split between the threads; reduction(+:sum) gives each thread a private sum
 * and adds them at the end (without it the threads race on sum and RESULT is wrong).
 * Prints: PROGRAM: pi_omp N: <N>, then RESULT: <pi> TIME: <s> WORKERS: <threads>.
 */
#include <omp.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    long long n = argc > 1 ? (long long)strtod(argv[1], NULL) : 1000000000LL;
    if (n < 1) {
        fprintf(stderr, "usage: %s [N > 0]\n", argv[0]);
        return 1;
    }
    double h = 1.0 / (double)n, sum = 0.0;
    double t0 = omp_get_wtime();
#pragma omp parallel for reduction(+:sum) schedule(static)
    for (long long i = 0; i < n; i++) {
        double x = h * ((double)i + 0.5);
        sum += 4.0 / (1.0 + x * x);
    }
    double pi = h * sum;
    double t = omp_get_wtime() - t0;
    printf("PROGRAM: pi_omp N: %lld\n", n);
    printf("RESULT: %.15f TIME: %.4f WORKERS: %d\n", pi, t, omp_get_max_threads());
    fflush(stdout);
    return 0;
}
