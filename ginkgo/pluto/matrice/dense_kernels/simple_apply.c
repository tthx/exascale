#include <stdlib.h>
#include <math.h>
void simple_apply(
  const size_t a_size_1,
  const size_t c_size_0,
  const size_t c_size_1,
  const size_t a_stride,
  const size_t b_stride,
  const size_t c_stride,
  const double_t **a_values,
  const double_t **b_values,
  double_t **c_values) {
  size_t i, j, k;
#pragma scop
  for (i = 0; i < c_size_0; ++i)
    for (j = 0; j < c_size_1; ++j)
      c_values[i][j] = 0;
  for (i = 0; i < c_size_0; ++i)
    for (j = 0; j < a_size_1; ++j)
      for (k = 0; k < c_size_1; ++k)
        c_values[i][k] += a_values[i][j] * b_values[j][k];
#pragma endscop
}
