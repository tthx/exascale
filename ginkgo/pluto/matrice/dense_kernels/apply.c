#include <stdlib.h>
#include <math.h>
void apply(
  const size_t a_size_1,
  const size_t c_size_0,
  const size_t c_size_1,
  const size_t a_stride,
  const size_t b_stride,
  const size_t c_stride,
  const double_t **a_values,
  const double_t **b_values,
  const double_ valpha,
  const double_t vbeta,
  double_t **c_values) {
  size_t i, j, k;
  if (is_nonzero(vbeta)) {
#pragma scop
    for (i = 0; i < c_size_0; ++i)
      for (j = 0; j < c_size_1; ++j)
        c_values[i][j] *= vbeta;
#pragma endscop
  } else {
#pragma scop
    for (i = 0; i < c_size_0; ++i)
      for (j = 0; j < c_size_1; ++j)
        c_values[i][j] = 0;
#pragma endscop
  }
#pragma scop
  for (i = 0; i < c_size_0; ++i)
    for (j = 0; j < a_size_1; ++j)
      for (k = 0; k < c_size_1; ++k)
        c_values[i][k] += valpha * a_values[i][j] * b_values[j][k];
#pragma endscop
}
