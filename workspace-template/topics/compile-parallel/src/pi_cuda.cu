/* pi_cuda.cu: the pi_serial.c integral on one GPU (stretch item, TAILOR.md).
 *
 *   build:  nvcc -O2 -arch=sm_86 -o build/pi_cuda src/pi_cuda.cu    (A40 = sm_86; no GPU needed to compile)
 *   run:    build/pi_cuda [N]                                        (in job.cuda.sbatch, on one A40)
 *
 * Each thread sums a grid-stride share of the intervals in double precision, each block reduces
 * its threads' sums in shared memory, and one atomicAdd per block adds the block sum to the total.
 * TIME covers the kernel only (CUDA events), after one warm-up launch.
 * Prints: PROGRAM: pi_cuda N: <N>, then RESULT: <pi> TIME: <s> WORKERS: <GPU threads>.
 */
#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

#define THREADS 256

#define CHECK(call)                                                                   \
    do {                                                                              \
        cudaError_t e_ = (call);                                                      \
        if (e_ != cudaSuccess) {                                                      \
            fprintf(stderr, "CUDA error %s at %s:%d\n", cudaGetErrorString(e_),       \
                    __FILE__, __LINE__);                                              \
            return 1;                                                                 \
        }                                                                             \
    } while (0)

__global__ void pi_kernel(long long n, double h, double *total)
{
    __shared__ double part[THREADS];
    double s = 0.0;
    long long stride = (long long)gridDim.x * blockDim.x;
    for (long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x; i < n; i += stride) {
        double x = h * ((double)i + 0.5);
        s += 4.0 / (1.0 + x * x);
    }
    part[threadIdx.x] = s;
    __syncthreads();
    for (int k = blockDim.x / 2; k > 0; k >>= 1) {
        if (threadIdx.x < k) part[threadIdx.x] += part[threadIdx.x + k];
        __syncthreads();
    }
    if (threadIdx.x == 0) atomicAdd(total, part[0]);
}

int main(int argc, char **argv)
{
    long long n = argc > 1 ? (long long)strtod(argv[1], NULL) : 1000000000LL;
    if (n < 1) {
        fprintf(stderr, "usage: %s [N > 0]\n", argv[0]);
        return 1;
    }
    int dev = 0, sms = 0;
    CHECK(cudaGetDevice(&dev));
    CHECK(cudaDeviceGetAttribute(&sms, cudaDevAttrMultiProcessorCount, dev));
    int blocks = sms * 8;
    double h = 1.0 / (double)n, sum = 0.0, *d_total;
    CHECK(cudaMalloc(&d_total, sizeof(double)));

    CHECK(cudaMemset(d_total, 0, sizeof(double)));  /* warm-up launch: context and module load */
    pi_kernel<<<blocks, THREADS>>>(n < 1000000 ? n : 1000000, h, d_total);
    CHECK(cudaDeviceSynchronize());

    cudaEvent_t a, b;
    CHECK(cudaEventCreate(&a));
    CHECK(cudaEventCreate(&b));
    CHECK(cudaMemset(d_total, 0, sizeof(double)));
    CHECK(cudaEventRecord(a));
    pi_kernel<<<blocks, THREADS>>>(n, h, d_total);
    CHECK(cudaGetLastError());
    CHECK(cudaEventRecord(b));
    CHECK(cudaEventSynchronize(b));
    float ms = 0.0f;
    CHECK(cudaEventElapsedTime(&ms, a, b));
    CHECK(cudaMemcpy(&sum, d_total, sizeof(double), cudaMemcpyDeviceToHost));
    CHECK(cudaFree(d_total));

    printf("PROGRAM: pi_cuda N: %lld\n", n);
    printf("RESULT: %.15f TIME: %.4f WORKERS: %d\n", h * sum, ms / 1000.0, blocks * THREADS);
    fflush(stdout);
    return 0;
}
