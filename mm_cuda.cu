#include "common.h"
#include <chrono>
#include <cstdio>
#include <cuda_runtime.h>
#include <iostream>

using namespace std;

void fill_matrix(int *m, int n) {
  for (int i = 0; i < n * n; i++) {
    m[i] = i;
  }
}

void check_result(int *m1, int *m2, int n) {
  int are_identical = 1;
  for (int i = 0; i < n; i++) {
    if (m1[i] != m2[i]) {
      are_identical = 0;
    }
  }
  if (are_identical) {
    cout << "Valid result." << endl;
  } else {
    cout << "invalid result." << endl;
  }
}

void multiply_seq(int *a, int *b, int *c, int n) {
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      c[j * n + i] = 0;
      for (int k = 0; k < n; k++) {
        c[j * n + i] += a[j * n + k] * b[i + k * n];
      }
    }
  }
}

__global__ void multiply(int *a, int *b, int *c, int n) {
  unsigned int i = threadIdx.x + blockIdx.x * blockDim.x;
  unsigned int j = threadIdx.y + blockIdx.y * blockDim.y;
  unsigned int idx = j * n + i;

  if (j < n && i < n) {
    int res = 0;
    for (int k = 0; k < n; k++) {
      res += a[j * n + k] * b[k * n + i];
    }
    c[idx] = res;
  }
}

int main(int argc, char *argv[]) {
  auto start_prog = chrono::high_resolution_clock::now();

  int n = 5;

  if (argc > 1) {
    n = atoi(argv[1]);
  }

  // set up device
  int dev = 0;
  cudaDeviceProp deviceProp;
  SAFE_CALL(cudaGetDeviceProperties(&deviceProp, dev), "Error device prop");
  printf("Using Device %d: %s\n", dev, deviceProp.name);
  SAFE_CALL(cudaSetDevice(dev), "Error setting device");

  // set up data size of matrix

  int *a = (int *)calloc(n * n, sizeof(int));
  int *b = (int *)calloc(n * n, sizeof(int));
  int *c = (int *)calloc(n * n, sizeof(int));
  int *d = (int *)calloc(n * n, sizeof(int));

  // initialize data at host side

  fill_matrix(a, n);
  fill_matrix(b, n);

  // malloc device global memory
  int *d_a, *d_b, *d_c;
  SAFE_CALL(cudaMalloc((void **)&d_a, n * n * sizeof(int)),
            "Error allocating d_a");
  SAFE_CALL(cudaMalloc((void **)&d_b, n * n * sizeof(int)),
            "Error allocating d_b");
  SAFE_CALL(cudaMalloc((void **)&d_c, n * n * sizeof(int)),
            "Error allocating d_c");

  // transfer data from host to device
  SAFE_CALL(cudaMemcpy(d_a, a, n * n * sizeof(int), cudaMemcpyHostToDevice),
            "Error copying a");
  SAFE_CALL(cudaMemcpy(d_b, b, n * n * sizeof(int), cudaMemcpyHostToDevice),
            "Error copying b");

  // invoke kernel at host side
  int dimx = 32;
  int dimy = 32;
  dim3 block(dimx, dimy);
  dim3 grid((n + block.x - 1) / block.x, (n + block.y - 1) / block.y);

  auto start_cpu = chrono::high_resolution_clock::now();
  multiply<<<grid, block>>>(d_a, d_b, d_c, n);
  SAFE_CALL(cudaDeviceSynchronize(), "Error executing kernel");
  auto end_cpu = chrono::high_resolution_clock::now();

  // SAFE_CALL kernel error
  SAFE_CALL(cudaGetLastError(), "Error with last error");

  // copy kernel result back to host side
  SAFE_CALL(cudaMemcpy(c, d_c, n * n * sizeof(int), cudaMemcpyDeviceToHost),
            "Error copying c");

  multiply_seq(a, b, d, n);

  // check device results
  check_result(c, d, n);

  // free device global memory
  SAFE_CALL(cudaFree(d_a), "Error freeing memory");
  SAFE_CALL(cudaFree(d_b), "Error freeing memory");
  SAFE_CALL(cudaFree(d_c), "Error freeing memory");

  // free host memory
  free(a);
  free(b);
  free(c);
  free(d);

  auto end_prog = chrono::high_resolution_clock::now();

  chrono::duration<float, std::milli> duration_ms = end_cpu - start_cpu;
  chrono::duration<float, std::milli> duration_ms_prog = end_prog - start_prog;

  cout << "multiply <<<(" << grid.x << ", " << grid.y << "), (" << block.x
       << ", " << block.y << ")>>> elapsed " << duration_ms.count()
       << "ms, with a total run time of " << duration_ms_prog.count() << "ms." << endl;

  // reset device
  SAFE_CALL(cudaDeviceReset(), "Error reseting");

  return 0;
}