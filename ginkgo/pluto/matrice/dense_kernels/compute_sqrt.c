#include <math.h>
#include <stdlib.h>
void compute_sqrt(
  const size_t data_size_0,
  const size_t data_size_1,
  const size_t data_stride,
  double_t **data_values) {
  size_t i, j;
#pragma scop
  for (i = 0; i < data_size_0; ++i)
    for (j = 0; j < data_size_1; ++j)
       data_values[i][j] = sqrt(data_values[i][j]);
#pragma endscop
}
