/* pi_mpi.c: the pi_serial.c integral with MPI ranks (one process per rank).
 *
 *   srun --ntasks=16 --cpus-per-task=1 build/pi_mpi [N]     (on Delta: srun, never mpirun)
 *
 * Rank r sums its own contiguous block of the N intervals; MPI_Reduce adds the partial
 * sums on rank 0, which prints: PROGRAM: pi_mpi N: <N>, then RESULT: <pi> TIME: <s> WORKERS: <ranks>.
 * TIME is the slowest rank's loop plus the reduction (barrier first, so all ranks start together).
 */
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    int rank, size;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    long long n = argc > 1 ? (long long)strtod(argv[1], NULL) : 1000000000LL;
    if (n < 1) {
        if (rank == 0) fprintf(stderr, "usage: %s [N > 0]\n", argv[0]);
        MPI_Finalize();
        return 1;
    }
    long long lo = n * rank / size, hi = n * (rank + 1) / size;
    double h = 1.0 / (double)n, local = 0.0, sum = 0.0;
    MPI_Barrier(MPI_COMM_WORLD);
    double t0 = MPI_Wtime();
    for (long long i = lo; i < hi; i++) {
        double x = h * ((double)i + 0.5);
        local += 4.0 / (1.0 + x * x);
    }
    MPI_Reduce(&local, &sum, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    double t = MPI_Wtime() - t0;
    if (rank == 0) {
        printf("PROGRAM: pi_mpi N: %lld\n", n);
        printf("RESULT: %.15f TIME: %.4f WORKERS: %d\n", h * sum, t, size);
        fflush(stdout);
    }
    MPI_Finalize();
    return 0;
}
