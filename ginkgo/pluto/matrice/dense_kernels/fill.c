#include <math.h>
#include <stdlib.h>
void fill(
  const size_t mat_size_0,
  const size_t mat_size_1,
  double **mat_values,
  const double_t value) {
  size_t i, j;
#pragma scop
  for (i = 0; i < mat_size_0; ++i) {
    for (j = 0; j < mat_size_1; ++j)
       mat_values[i][j] = value;
  }
#pragma endscop
}
