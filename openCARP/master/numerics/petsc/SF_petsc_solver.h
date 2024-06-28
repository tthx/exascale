#ifndef _SF_PETSC_SOLVER_H
#define _SF_PETSC_SOLVER_H
#ifdef WITH_PETSC

#include <petscmat.h>
#include <petscksp.h>

#include "basics.h"
#include "petsc_compat.h"

#include "SF_abstract_lin_solver.h"
#include "SF_globals.h"

#include "SF_petsc_vector.h"
#include "SF_petsc_matrix.h"


namespace SF {

/**
 * @brief A class encapsulating a PETSc solver.
 *
 * @note Objects of this class should not be used or initialized directly.
 *       Instead, use virtual functions on the abstract_linera_solver base
 *       type and use the init_solver() function from numerics/SF_init.h.
 *
 * @see abstract_linear_solver
 * @see numerics/SF_init.h
 */
template<class T, class S>
struct petsc_solver:public abstract_linear_solver<T,S> {
  using norm_t=typename abstract_linear_solver<T,S>::norm_t;
  petsc_matrix<T,S> *matrix=NULL;
  bool check_start_norm=false;
  KSP ksp=NULL;
  MatNullSpace nullspace=NULL;

  void operator ()(abstract_vector<T,S> &x_,
                   const abstract_vector<T,S> &b_) override {
    auto &x=dynamic_cast<petsc_vector<T,S> &>(x_);
    auto &b=dynamic_cast<const petsc_vector<T,S> &>(b_);
    assert(x.data!=b.data);
    assert(ksp!=NULL);
    const double solve_zero=1e-16;
    const double NORMB=check_start_norm ? b.mag():1.0;
    if(NORMB>solve_zero) {
      PetscCallVoid(KSPSolve(ksp, b.data, x.data));
      PetscCallVoid(KSPGetIterationNumber(ksp,
                                          &(abstract_linear_solver<T,S>::niter)));
      KSPConvergedReason r;
      PetscCallVoid(KSPGetConvergedReason(ksp, &r));
      abstract_linear_solver<T,S>::reason=int(r);
      PetscCallVoid(KSPGetResidualNorm(ksp,
                                       &(abstract_linear_solver<T,S>::final_residual)));
    } else {
      abstract_linear_solver<T,S>::niter=0;
      abstract_linear_solver<T,S>::final_residual=NORMB;
    }
  }

  void setup_solver(abstract_matrix<T, S>& mat,
                    double tol,
                    int max_it,
                    short norm,
                    std::string name,
                    bool has_nullspace,
                    void *logger,
                    const char *solver_opts_file,
                    const char *default_opts) override;

  protected:
  void set_stopping_criterion(norm_t normtype,
                              double tol,
                              int max_it,
                              bool verbose,
                              void *logger) override;

  /** insert petsc solver options file
   *
   * @param default_opts_str  string with default options. used if no options file provided.
   * @param verbose  Whether to be verbose or not.
   * @param logger   The file descriptor we write to if we are verbose.
   *
   * @returns  0, if successful
   *          -1, otherwise, i.e. options file not found
   */
  int insert_solver_opts(const char *default_ops_str,
                         bool verbose,
                         opencarp::FILE_SPEC logger);
};


template<class T, class S>
void init_solver_petsc(abstract_linear_solver<T,S> **sol);

}  // namespace SF

#endif // WITH_PETSC
#endif // _SF_PETSC_SOLVER_H
