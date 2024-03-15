#include <stdlib.h>
#include <math.h>
void compute_norm1(
  const size_t x_size_0,
  const size_t x_size_1,
  const size_t x_stride,
  const double_t **x_values,
  double_t *result_values) {
  size_t i, j;
#pragma scop
  for (j = 0; j < x_size_1; ++j)
    result_values[j] = 0;
  for (i = 0; i < x_size_0; ++i)
    for (j = 0; j < x_size_1; ++j)
      result_values[j] += abs(x_values[i][j]);
#pragma endscop
}
