#include <stdio.h>
#include <math.h>
void fill_in_matrix_data(
    const size_t data_num_elems,
    const double_t **output_stride,
    double_t **output_values) {
#pragma scop
    for (size_type i = 0; i < data_num_elems; i++) {
        output_values[i][i] = data_values[i];
    }
#pragma endscop
}
