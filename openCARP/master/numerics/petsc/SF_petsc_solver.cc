#include <iomanip>
#include <string>

#include "SF_petsc_solver.h"

#include "petsc_utils.h"

namespace SF {

template <class T, class S>
void petsc_solver<T, S>::set_stopping_criterion(norm_t normtype,
                                                double tol,
                                                int max_it,
                                                bool verbose,
                                                void *void_logger) {
  auto logger=reinterpret_cast<opencarp::FILE_SPEC>(void_logger);
  double absTol=tol;
  double relTol=absTol;

  this->norm=normtype;
  this->max_it=max_it;
  switch(normtype) {
    case norm_t::absPreResidual:
      // make sure that we do not converge due to relative stopping criterion
      relTol=1e-50;
      PetscCallVoid(KSPSetNormType(this->ksp, KSP_NORM_PRECONDITIONED));
      if(verbose)
        opencarp::log_msg(logger,
                          0,
                          0,
                          "Solving %s system using absolute tolerance (%g) of preconditioned residual\n"
                          "as stopping criterion",
                          this->name.c_str(),
                          absTol);
      break;

    case norm_t::absUnpreResidual:
      // make sure that we do not converge due to relative stopping criterion
      relTol=1e-50;
      PetscCallVoid(KSPSetNormType(this->ksp, KSP_NORM_UNPRECONDITIONED));
      // this is not possible with all iterative methods, ideally we would issue
      // an error message here to inform the user
      if (verbose)
        opencarp::log_msg(logger,
                          0,
                          0,
                          "Solving %s system using absolute tolerance (%g) of unpreconditioned residual\n"
                          "as stopping criterion",
                          this->name.c_str(),
                          absTol);
      break;

    case norm_t::relResidual:
      // make sure that we do not converge due to absolute stopping criterion
      absTol=0.0;
      if (verbose)
        opencarp::log_msg(logger,
                          0,
                          0,
                          "Solving %s system using relative tolerance (%g)\n"
                          "as stopping criterion",
                          this->name.c_str(),
                          relTol);
      break;

    case norm_t::absPreRelResidual:
      if (verbose)
        opencarp::log_msg(logger,
                          0,
                          0,
                          "Solving %s system using combined relative and absolute tolerance (%g)\n"
                          "as stopping criterion (preconditioned L2 is used)",
                          this->name.c_str(),
                          absTol);
      break;

    default:
      opencarp::log_msg(logger,
                        2,
                        0,
                        "Chosen stopping criterion invalid, defaulting to absolute tolerance of preconditioned residual");
      relTol=1e-50;
  }

  PetscCallVoid(KSPSetTolerances(this->ksp,
                                 relTol,
                                 absTol,
                                 PETSC_DEFAULT,
                                 this->max_it));
}

template <class T, class S>
int petsc_solver<T, S>::insert_solver_opts(const char *default_opts_str,
                                           bool verbose,
                                           opencarp::FILE_SPEC logger) {
  int ierr=0;
  auto opt_file=this->options_file;
  // in either case we use command line options
  // we have to be careful with that though, we should not set any solver specific
  // options here. Typically, we would set options such as
  // -ksp_monitor -ksp_view -ksp_norm_type etc
  PetscCall(KSPSetFromOptions(this->ksp));

  if (std::strcmp(opt_file, "")==0) {
    opencarp::log_msg(logger,
                      0,
                      0,
                      "%s solver: switching to default settings \"%s\".",
                      this->name.c_str(),
                      default_opts_str);
    PetscCall(PetscOptionsInsertString(PETSC_NULLPTR, default_opts_str));
    PetscCall(KSPSetFromOptions(this->ksp));
    PetscCall(opencarp::PetscOptionsClearFromString(default_opts_str));
    // check whether solver is direct
    PC pc;
    PCType type;
    PetscCall(KSPGetPC(this->ksp, &pc));
    PetscCall(PCGetType(pc, &type));
    if((!strcmp(type, PCLU)) ||
       (!strcmp(type, PCCHOLESKY))) {
      PetscCall(KSPSetType(this->ksp, "preonly"));
      PetscCall(KSPSetInitialGuessNonzero(this->ksp, PETSC_FALSE));
      PetscCall(KSPSetNormType(this->ksp, KSP_NORM_NONE));
    }
  } else if(opencarp::file_can_be_opened(opt_file)) {
    if(verbose)
      opencarp::log_msg(logger,
                        0,
                        0,
                        "%s solver: switching to user-provided settings given in %s",
                        this->name.c_str(),
                        opt_file);
    // insert options file
    PetscCall(PetscOptionsInsertFile(PETSC_COMM_WORLD,
                                     PETSC_NULLPTR,
                                     opt_file,
                                     PETSC_FALSE));
    PetscCall(KSPSetFromOptions(this->ksp));
    PetscCall(opencarp::PetscOptionsClearFromFile(PETSC_COMM_WORLD, opt_file));
    // check whether solver is direct
    PC pc;
    PCType type;
    PetscCall(KSPGetPC(this->ksp, &pc));
    PetscCall(PCGetType(pc, &type));
    if((!strcmp(type, PCLU)) ||
       (!strcmp(type, PCCHOLESKY))) {
      PetscCall(KSPSetType(this->ksp, "preonly"));
      PetscCall(KSPSetInitialGuessNonzero(this->ksp, PETSC_FALSE));
      PetscCall(KSPSetNormType(this->ksp, KSP_NORM_NONE));
    }
  } else {
    opencarp::log_msg(0,
                      4,
                      0,
                      "%s solver: user-provided options file %s could not be read.",
                      this->name.c_str(),
                      opt_file);
    ierr=-1;
  }
  return ierr;
}

template <typename T, typename S>
void petsc_solver<T, S>::setup_solver(abstract_matrix<T, S> &mat,
                                      double tol,
                                      int max_it,
                                      short norm,
                                      std::string name,
                                      bool has_nullspace,
                                      void *void_logger,
                                      const char *solver_opts_file,
                                      const char *default_opts) {
  auto &petsc_mat=dynamic_cast<petsc_matrix<T,S>&>(mat);
  auto logger=reinterpret_cast<opencarp::FILE_SPEC>(void_logger);
  if(this->ksp!=NULL)
    PetscCallVoid(KSPDestroy(&this->ksp));
  auto str_name=name+" (PETSc)";
  this->name=str_name;
  this->options_file=solver_opts_file;
  this->matrix=&petsc_mat;
  // create KSP
  PetscCallVoid(KSPCreate(PETSC_COMM_WORLD, &this->ksp));
  // non time-varying keep preconditioner
  PetscCallVoid(KSPSetOperators(this->ksp, petsc_mat.data, petsc_mat.data));
  // additional settings for solving singular systems; only works if the null
  // space is the constant vector, see matnull.c in PetSc for more information
  if(has_nullspace) {
    PetscBool hasConstant=PETSC_TRUE; // null space contains the constant vector
    int numVec=0; // number of vectors (excluding constant vector) in null space
    // vecs=NULL // vectors that span the null space (excluding constant vector)
    PetscCallVoid(MatNullSpaceCreate(PETSC_COMM_WORLD,
                                     hasConstant,
                                     numVec,
                                     NULL,
                                     &this->nullspace));
    PetscCallVoid(MatSetNullSpace(petsc_mat.data,
                                  this->nullspace));
    //MatNullSpaceDestroy(&m->nullsp);
  }
  // reusing the same preconditioner?
  PetscCallVoid(KSPSetReusePreconditioner(this->ksp, PETSC_TRUE));
  PetscCallVoid(KSPSetType(this->ksp, KSPCG));
  PetscCallVoid(MatSetOption(petsc_mat.data, MAT_SYMMETRIC, PETSC_TRUE));
#if PETSC_VERSION >= 35000
  // set matrix block size (i.e. number of dof per node
  PetscCallVoid(MatSetBlockSize(petsc_mat.data, 1));
#endif
  // use initial guess
  PetscCallVoid(KSPSetInitialGuessNonzero(this->ksp, PETSC_TRUE));
  auto normtype=this->convert_param_norm_type(param_globals::cg_norm_ellip);
  bool verbose=true;
  this->set_stopping_criterion(normtype, tol, max_it, verbose, logger);
  this->insert_solver_opts(default_opts, verbose, logger);
}

#define OPENCARP_DECLARE_PETSC_SOLVER(IndexType, ValueType) \
class petsc_solver<IndexType, ValueType>
OPENCARP_INSTANTIATE_FOR_EACH_VALUE_AND_INDEX_TYPE(OPENCARP_DECLARE_PETSC_SOLVER);

template<class T, class S>
void init_solver_petsc(abstract_linear_solver<T,S>** sol) {
  *sol=new petsc_solver<T,S>();
}

#define OPENCARP_DECLARE_INIT_SOLVER(IndexType, ValueType) \
void init_solver_petsc<IndexType, ValueType>(abstract_linear_solver<IndexType,ValueType>**)
OPENCARP_INSTANTIATE_FOR_EACH_VALUE_AND_INDEX_TYPE(OPENCARP_DECLARE_INIT_SOLVER);


}  // namespace SF
