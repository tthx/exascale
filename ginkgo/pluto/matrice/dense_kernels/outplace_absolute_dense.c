#include <stdlib.h>
#include <math.h>
void outplace_absolute_dense(
  const size_t source_stride,
  const double_t **source_values,
  double_t **result_values,
  const size_t dim_0,
  const size_t dim_1)
  size_t row, col;
#pragma scop
  for (row = 0; row < dim_0; row++)
    for (col = 0; col < dim_1; col++)
      result_values[row][col] = abs(source_values[row][col]);
#pragma endscop
}
