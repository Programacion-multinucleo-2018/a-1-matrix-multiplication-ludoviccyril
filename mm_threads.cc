#include <chrono>
#include <cmath>
#include <iostream>
#include <omp.h>
#include <string>

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

void multiply(int *a, int *b, int *c, int n, int t) {
  int k = 0;
  int i = 0;
  int j = 0;
  omp_set_num_threads(t);
#pragma omp parallel for private(i, j, k) shared(a, b, c, n)
  for (i = 0; i < n; i++) {
    for (j = 0; j < n; j++) {
      c[j * n + i] = 0;
      for (k = 0; k < n; k++) {
        c[j * n + i] += a[j * n + k] * b[i + k * n];
      }
    }
  }
}

int main(int argc, char *argv[]) {
  auto start_prog = chrono::high_resolution_clock::now();

  int n = 5;

  if (argc > 1) {
    n = atoi(argv[1]);
  }

  int t = 4;

  if (argc > 2) {
    t = atoi(argv[2]);
  }

  int *a = new int[n * n];
  int *b = new int[n * n];
  int *c = (int *)calloc(n * n, sizeof(int));
  int *d = (int *)calloc(n * n, sizeof(int));

  fill_matrix(a, n);
  fill_matrix(b, n);

  auto start_calc = chrono::high_resolution_clock::now();

  multiply(a, b, c, n, t);

  auto end_calc = chrono::high_resolution_clock::now();

  multiply_seq(a, b, d, n);
  check_result(c, d, n);

  delete[] a;
  delete[] b;
  delete[] c;
  delete[] d;

  auto end_prog = chrono::high_resolution_clock::now();

  chrono::duration<float, std::milli> duration_calc = end_calc - start_calc;
  chrono::duration<float, std::milli> duration_prog = end_prog - start_prog;

  cout << endl
       << "Spent " << duration_calc.count() << "ms multiplying, spent "
       << duration_prog.count() << "ms running the program with " << t
       << " threads." << endl
       << endl;
}