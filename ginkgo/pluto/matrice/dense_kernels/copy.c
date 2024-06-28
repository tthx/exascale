#include <stdlib.h>
#include <math.h>
void copy(
  const size_t input_size_0,
  const size_t input_size_1,
  const size_t input_stride,
  const double_t output_stride,
  const double_t **input_values,
  double_t **output_values) {
  size_t i, j;
#pragma scop
  for (i = 0; i < input_size_0; ++i)
    for (j = 0; j < input_size_1; ++j)
       output_values[i][j] = input_values[i][j];
#pragma endscop
}
