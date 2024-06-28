#ifndef _SF_PETSC_MATRIX_H
#define _SF_PETSC_MATRIX_H

#include "SF_abstract_matrix.h"

#ifdef WITH_PETSC

#include <cassert>

#include <petscmat.h>

#include "SF_globals.h"
#include "SF_petsc_vector.h"
#include "petsc_compat.h"


namespace SF {

/**
 * @brief A class encapsulating a Ginkgo matrix.
 *
 * @note Objects of this class should not be used or initialized directly.
 *       Instead, use virtual functions on the abstract_matrix base type and
 *       use the init_matrix() function from numerics/SF_init.h.
 *
 * @see abstract_matrix
 * @see numerics/SF_init.h
 */
template <class T, class S>
class petsc_matrix:public abstract_matrix<T, S> {
  public:
  /// the petsc Mat object
  mutable Mat data;

  /** Default constructor */
  petsc_matrix():abstract_matrix<T,S>::abstract_matrix(),
                 data(PETSC_NULLPTR) {}

  ~petsc_matrix() override {
    if(this->data)
      PetscCallVoid(MatDestroy(&this->data));
  }

  inline void init(T iNRows, T iNCols,
                   T ilrows, T ilcols,
                   T loc_offset, T mxent) override {
    // init member vars
    abstract_matrix<T,S>::init(iNRows, iNCols, ilrows, ilcols,
                               loc_offset, mxent);
    PetscCallVoid(MatCreateFromOptions(PETSC_COMM_WORLD,
                                       NULL, 1,
                                       ilrows, ilcols,
                                       this->NRows, this->NCols,
                                       &this->data));
    PetscCallVoid(MatSetFromOptions(this->data));
    PetscCallVoid(MatMPIAIJSetPreallocation(this->data,
                                            mxent, PETSC_NULLPTR,
                                            mxent, PETSC_NULLPTR));
    PetscCallVoid(MatSetOption(this->data,
                               MAT_KEEP_NONZERO_PATTERN,
                               PETSC_TRUE));
    PetscCallVoid(MatZeroEntries(this->data));
  }

  inline void init(const meshdata<mesh_int_t,
                                  mesh_real_t> &imesh,
                   const T irow_dpn,
                   const T icol_dpn,
                   const T max_edges) {
    abstract_matrix<T,S>::init(imesh, irow_dpn, icol_dpn, max_edges);
  }

  inline void zero() override {
    PetscCallVoid(MatZeroEntries(this->data));
  }

  inline void mult(const abstract_vector<T,S> &x_,
                   abstract_vector<T,S> &b_) const override {
    auto &x=dynamic_cast<const petsc_vector<T,S> &>(x_);
    auto &b=dynamic_cast<petsc_vector<T,S> &>(b_);
    PetscCallVoid(MatMult(this->data, x.data, b.data));
  }

  inline void mult_LR(const abstract_vector<T, S> &L_,
                      const abstract_vector<T, S> &R_) override {
    auto &L=dynamic_cast<const petsc_vector<T, S>&>(L_);
    auto &R=dynamic_cast<const petsc_vector<T, S>&>(R_);
    PetscCallVoid(MatDiagonalScale(this->data, L.data, R.data));
  }

  inline void diag_add(const abstract_vector<T, S> &diag_) override {
    auto &diag=dynamic_cast<const petsc_vector<T, S>&>(diag_);
    PetscCallVoid(MatDiagonalSet(this->data, diag.data, ADD_VALUES));
  }

  inline void get_diagonal(abstract_vector<T, S> &vec_) const override {
    auto &vec=dynamic_cast<petsc_vector<T, S>&>(vec_);
    PetscCallVoid(MatGetDiagonal(this->data, vec.data));
  }

  inline void finish_assembly() override {
    PetscCallVoid(MatAssemblyBegin(this->data, MAT_FINAL_ASSEMBLY));
    PetscCallVoid(MatAssemblyEnd(this->data, MAT_FINAL_ASSEMBLY));
  }

  inline void scale(S s) override {
    PetscCallVoid(MatScale(this->data, s));
  }

  inline void add_scaled_matrix(const abstract_matrix<T, S> &A_,
                                const S s,
                                const bool same_nnz) override {
    auto &A=dynamic_cast<const petsc_matrix<T, S>&>(A_);
    MatStructure NNZ=same_nnz?SAME_NONZERO_PATTERN:DIFFERENT_NONZERO_PATTERN;
    PetscCallVoid(MatAXPY(this->data, s, A.data, NNZ));
  }

  inline void duplicate(const abstract_matrix<T,S> &M_) override {
    auto &M=dynamic_cast<const petsc_matrix<T, S>&>(M_);
    this->NRows=M.NRows;
    this->NCols=M.NCols;
    this->row_dpn=M.row_dpn;
    this->col_dpn=M.col_dpn;
    this->lsize=M.lsize;
    this->start=M.start;
    this->stop=M.stop;
    this->mesh=M.mesh;
    if(this->data)
      PetscCallVoid(MatDestroy(&this->data));
    PetscCallVoid(MatDuplicate(M.data, MAT_COPY_VALUES, &this->data));
  }

  inline void set_values(const vector<T> &row_idx,
                         const vector<T> &col_idx,
                         const vector<S> &vals,
                         bool add) override {
    assert((row_idx.size()==col_idx.size()) &&
           (row_idx.size()==vals.size()));
    // add values into system matrix
    PetscCallVoid(MatSetValues(this->data,
                               row_idx.size(),
                               row_idx.data(),
                               col_idx.size(),
                               col_idx.data(),
                               vals.data(),
                               add?ADD_VALUES:INSERT_VALUES));
  }

  inline void set_values(const vector<T> &row_idx, const vector<T> &col_idx,
                         const S *vals, bool add) override {
    assert(row_idx.size()==col_idx.size());
    // add values into system matrix
    PetscCallVoid(MatSetValues(this->data,
                               row_idx.size(),
                               row_idx.data(),
                               col_idx.size(),
                               col_idx.data(),
                               vals,
                               add?ADD_VALUES:INSERT_VALUES));
  }

  inline void set_value(T row_idx, T col_idx, S val, bool add) override {
    PetscCallVoid(MatSetValue(this->data,
                              row_idx,
                              col_idx,
                              val,
                              add?ADD_VALUES:INSERT_VALUES));
  }

  inline S get_value(T row_idx, T col_idx) const override {
    S val;
    PetscCallAbort(PETSC_COMM_WORLD,
                   MatGetValues(this->data,
                                1, &row_idx,
                                1, &col_idx,
                                &val));
    return val;
  }

  inline void write(const char *filename) const override {
    PetscViewer viewer;
    PetscCallVoid(
      PetscViewerBinaryOpen(this->mesh?this->mesh->comm:PETSC_COMM_WORLD,
                            filename,
                            FILE_MODE_WRITE,
                            &viewer));
    PetscCallVoid(MatView(this->data, viewer));
    PetscCallVoid(PetscViewerDestroy(&viewer));
  }
};

template<class T, class S>
void init_matrix_petsc(abstract_matrix<T,S>** mat);

} // namespace SF

#endif // WITH_PETSC
#endif // _SF_PETSC_MATRIX_H
