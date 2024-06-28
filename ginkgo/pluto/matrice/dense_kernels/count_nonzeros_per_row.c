#include <math.h>
#include <stdlib.h>
void count_nonzeros_per_row(
  const size_t source_size_0,
  const size_t source_size_1,
  const size_t source_stride,
  const double_t **source,
  const double_t *result)
{
  size_t i, j, num_nonzeros;
#pragma scop
  for (i = 0; i < source_size_0; ++i) {
    num_nonzeros = 0;
    for (j = 0; j < source_size_1; ++j)
      num_nonzeros += source_values[i][j];
    result[i] = num_nonzeros;
  }
#pragma endscop
}
