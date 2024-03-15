#include <stdlib.h>
#include <math.h>
void transpose(
  const size_t orig_size_0,
  const size_t orig_size_1,
  const size_t orig_stride,
  const double_t **orig_values,
  const size_t trans_stride,
  double_t **trans_values) {
  size_t i, j;
#pragma scop
  for (i = 0; i < orig_size_0; ++i)
    for (j = 0; j < orig_size_1; ++j)
      trans_values[j][i] = orig_values[i][j];
#pragma endscop
}
