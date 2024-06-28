/*******************************<GINKGO LICENSE>******************************
Copyright (c) 2017-2023, the Ginkgo authors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
******************************<GINKGO LICENSE>*******************************/

#include "core/solver/cg_kernels.hpp"


#include <ginkgo/core/base/array.hpp>
#include <ginkgo/core/base/exception_helpers.hpp>
#include <ginkgo/core/base/math.hpp>
#include <ginkgo/core/base/types.hpp>


namespace gko {
namespace kernels {
namespace omp {
/**
 * @brief The CG solver namespace.
 *
 * @ingroup cg
 */
namespace cg {


template <typename ValueType>
void initialize(std::shared_ptr<const DefaultExecutor> exec,
                const matrix::Dense<ValueType>* b, matrix::Dense<ValueType>* r,
                matrix::Dense<ValueType>* z, matrix::Dense<ValueType>* p,
                matrix::Dense<ValueType>* q, matrix::Dense<ValueType>* prev_rho,
                matrix::Dense<ValueType>* rho,
                array<stopping_status>* stop_status)
{
#pragma omp parallel
    {
#pragma omp for simd nowait
        for (size_type j = 0; j < b->get_size()[1]; ++j) {
            rho->at(j) = zero<ValueType>();
            prev_rho->at(j) = one<ValueType>();
            stop_status->get_data()[j].reset();
        }
#pragma omp for simd collapse(2) nowait
        for (size_type i = 0; i < b->get_size()[0]; ++i) {
            for (size_type j = 0; j < b->get_size()[1]; ++j) {
                r->at(i, j) = b->at(i, j);
                z->at(i, j) = p->at(i, j) = q->at(i, j) = zero<ValueType>();
            }
        }
    }
}

GKO_INSTANTIATE_FOR_EACH_VALUE_TYPE(GKO_DECLARE_CG_INITIALIZE_KERNEL);


template <typename ValueType>
void step_1(std::shared_ptr<const DefaultExecutor> exec,
            matrix::Dense<ValueType>* p, const matrix::Dense<ValueType>* z,
            const matrix::Dense<ValueType>* rho,
            const matrix::Dense<ValueType>* prev_rho,
            const array<stopping_status>* stop_status)
{
#pragma omp parallel for
    for (size_type j = 0; j < p->get_size()[1]; ++j) {
        if (!stop_status->get_const_data()[j].has_stopped()) {
            const auto prev_rho_value = prev_rho->at(j);
            auto val = zero<ValueType>();
            if (is_nonzero(prev_rho_value)) {
                const auto rho_value = rho->at(j);
                if (is_nonzero(rho_value)) {
                    val = rho_value / prev_rho_value;
                }
            }
            if (is_zero(val)) {
#pragma omp simd
                for (size_type i = 0; i < p->get_size()[0]; ++i) {
                    p->at(i, j) = z->at(i, j);
                }
            } else {
                if (val != one<ValueType>()) {
#pragma omp simd
                    for (size_type i = 0; i < p->get_size()[0]; ++i) {
                        p->at(i, j) = z->at(i, j) + (val * p->at(i, j));
                    }
                } else {
#pragma omp simd
                    for (size_type i = 0; i < p->get_size()[0]; ++i) {
                        p->at(i, j) += z->at(i, j);
                    }
                }
            }
        }
    }
}

GKO_INSTANTIATE_FOR_EACH_VALUE_TYPE(GKO_DECLARE_CG_STEP_1_KERNEL);


template <typename ValueType>
void step_2(std::shared_ptr<const DefaultExecutor> exec,
            matrix::Dense<ValueType>* x, matrix::Dense<ValueType>* r,
            const matrix::Dense<ValueType>* p,
            const matrix::Dense<ValueType>* q,
            const matrix::Dense<ValueType>* beta,
            const matrix::Dense<ValueType>* rho,
            const array<stopping_status>* stop_status)
{
#pragma omp parallel for
    for (size_type j = 0; j < p->get_size()[1]; ++j) {
        if (!stop_status->get_const_data()[j].has_stopped()) {
            const auto rho_value = rho->at(j);
            auto val = zero<ValueType>();
            if (is_nonzero(rho_value)) {
                const auto beta_value = beta->at(j);
                if (is_nonzero(beta_value)) {
                    val = rho_value / beta_value;
                }
            }
            if (is_nonzero(val)) {
                if (val != one<ValueType>()) {
#pragma omp simd
                    for (size_type i = 0; i < p->get_size()[0]; ++i) {
                        x->at(i, j) += val * p->at(i, j);
                        r->at(i, j) -= val * q->at(i, j);
                    }
                } else {
#pragma omp simd
                    for (size_type i = 0; i < p->get_size()[0]; ++i) {
                        x->at(i, j) += p->at(i, j);
                        r->at(i, j) -= q->at(i, j);
                    }
                }
            }
        }
    }
}

GKO_INSTANTIATE_FOR_EACH_VALUE_TYPE(GKO_DECLARE_CG_STEP_2_KERNEL);


}  // namespace cg
}  // namespace omp
}  // namespace kernels
}  // namespace gko
