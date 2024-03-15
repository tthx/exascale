#include <stdlib.h>
#include <math.h>
void inplace_absolute_dense(
  const size_t source_stride,
  double_t **source_values,
  const size_t dim_0,
  const size_t dim_1)
  size_t row, col;
#pragma scop
  for (row = 0; row < dim_0; row++)
    for (col = 0; col < dim_1; col++)
      source_values[row][col] = abs(source_values[row][col]);
#pragma endscop
}
