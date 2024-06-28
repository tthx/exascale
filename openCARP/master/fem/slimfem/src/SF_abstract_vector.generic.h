// ----------------------------------------------------------------------------
// openCARP is an open cardiac electrophysiology simulator.
//
// Copyright (C) 2020 openCARP project
//
// This program is licensed under the openCARP Academic Public License (APL)
// v1.0: You can use and redistribute it and/or modify it in non-commercial
// academic environments under the terms of APL as published by the openCARP
// project v1.0, or (at your option) any later version. Commercial use requires
// a commercial license (info@opencarp.org).
//
// This program is distributed without any warranty; see the openCARP APL for
// more details.
//
// You should have received a copy of the openCARP APL along with this program
// and can find it online: http://www.opencarp.org/license
// ----------------------------------------------------------------------------

#ifndef _SF_ABSTRACT_VECTOR_H
#define _SF_ABSTRACT_VECTOR_H

#include <mpi.h>

#include <petscvec.h> // TODO: For scattering, VecScatter and friends
#include <petscis.h>
#include <petscsys.h> // TODO: For PETSC_COMM_WORLD

#include "SF_container.h"
#include "SF_globals.h"
#include "SF_parallel_layout.h"
#include "SF_parallel_utils.h"

#include "hashmap.hpp"

namespace SF {

// Forward declare the scattering class
class scattering;

/**
 * An abstract class representing a (possibly distributed) vector.
 *
 * It is connected to a mesh and offers some convenience features w.r.t. setup
 * and function calls. This is an interface definition, for concrete
 * implementations see the petsc_vector or ginkgo_vector classes.
 *
 * @tparam T  Integer type (indices).
 * @tparam S  Floating point type (values).
 *
 * @see ginkgo_vector
 * @see petsc_vector
 */
template<class T, class S>
class abstract_vector {

  public:

  /** Enumeration of layout types for the vector */
  enum ltype {algebraic, nodal, elemwise, unset};

  const meshdata<mesh_int_t,mesh_real_t> *mesh=NULL; ///< the connected mesh
  int dpn=0; ///< d.o.f. per mesh vertex.
  ltype layout=unset; ///< used vector layout (nodal, algebraic, unset)

  /** Default destructor */
  virtual ~abstract_vector()=default;

  /**
   * Init the vector dimensions based on a give mesh.
   *
   * @param imesh       The mesh defining the parallel layout of the vector.
   * @param idpn        The number of d.o.f. per mesh vertex.
   * @param inp_layout  The vector layout.
   */
  virtual void init(const meshdata<mesh_int_t, mesh_real_t> &imesh,
                    int idpn,
                    ltype inp_layout)=0;

  /**
   * Initialize a vector from the setup of another given vector.
   *
   * @param vec Vector to replicate the setup from.
   */
  virtual void init(const abstract_vector<T, S> &vec)=0;

  /**
   * Initialize a vector directly with set sizes.
   *
   * @param igsize  Global size
   * @param ilsize  Local size
   * @param idpn    Number of d.o.f. used per mesh node
   * @param ilayout Vector layout w.r.t. used mesh.
   */
  virtual void init(int igsize,
                    int ilsize,
                    int idpn=1,
                    ltype ilayout=unset)=0;

  /**
   * Non backend-specific vector initialization based on a mesh.
   *
   * @param imesh       The mesh defining the parallel layout of the vector.
   * @param idpn        The number of d.o.f. per mesh vertex.
   * @param inp_layout  The vector layout.
   *
   * @returns a tuple with computed sizes N and n.
   */
  inline std::tuple<int, int> init_common(const meshdata<mesh_int_t,
                                                         mesh_real_t> &imesh,
                                          int idpn,
                                          ltype inp_layout)
  {
    mesh=&imesh;
    dpn=idpn;
    int N=0, n=0;

    switch(inp_layout) {
      case algebraic:
        N=mesh->pl.num_global_idx()*dpn;
        n=mesh->pl.num_algebraic_idx()*dpn;
        layout=algebraic;
        break;

      case nodal:
        N=mesh->l_numpts*dpn;
        PetscCallMPIAbort(PETSC_COMM_WORLD,
                          MPI_Allreduce(MPI_IN_PLACE,
                                        &N, 1,
                                        MPI_INT, MPI_SUM,
                                        mesh->comm));
        n=mesh->l_numpts*dpn;
        layout=nodal;
        break;

      case elemwise:
        N=mesh->g_numelem;
        n=mesh->l_numelem;
        layout=elemwise;
        break;

      default: break;
    }

    return std::tuple<int, int>(N, n);
  }

  /**
   * Set the vector values.
   *
   * @param idx       The global indices where to set.
   * @param vals      The values to set.
   * @param additive  Whether to add into the current values or overwrite them.
   */
  virtual void set(const vector<T> &idx,
                   const vector<S> &vals,
                   const bool additive=false)=0;

  /**
   * Set the specified vector indices to one value.
   *
   * @param idx  The indices where to set.
   * @param val  The value to set.
   */
  virtual void set(const vector<T>& idx, const S val)=0;

  /**
   * Set the whole vector to one value.
   *
   * @param val  The value to set.
   */
  virtual void set(const S val)=0;

  /**
   * Set one index to a specific value.
   *
   * @param idx  The index to be set.
   * @param val  The value to set.
   *
   * @note Caution: repetitive use of this function can be very inefficient!
   */
  virtual void set(const T idx, const S val)=0;

  /**
   * Get the values at the requested indices
   *
   * @param idx  The indices to get.
   * @param out  The values at the requested indices.
   *
   */
  virtual void get(const vector<T> &idx, S *out)=0;

  /**
   * Get the value of one index
   *
   * @param idx  The index to get.
   *
   * @returns the requested value
   */
  virtual S get(const T idx)=0;

  /**
   * Convenient operator overload to multiply the vector by a scalar.
   *
   * @param sca  The scalar to multiply the vector by.
   */
  virtual void operator *=(const S sca)=0;

  /**
   * Convenient operator overload to divide the vector by a scalar.
   *
   * @param sca  The scalar to divide the vector by.
   */
  virtual void operator /=(const S sca)=0;

  /**
   * Convenient operator overload to multiply the vector by another.
   *
   * @param vec  The second vector to multiply this vector with.
   */
  virtual void operator *=(const abstract_vector<T, S>& vec)=0;

  /**
   * Adds vec scaled by k to this vector (i.e., BLAS axpy).
   *
   * @param vec  The second vector to scale and multiply this vector with.
   * @param k    The scalar.
   */
  virtual void add_scaled(const abstract_vector<T, S> &vec, S k)=0;

  /**
   * Convenient operator overload to add the vector with another.
   *
   * @param vec  The second vector to add this vector with.
   */
  virtual void operator +=(const abstract_vector<T,S> &vec)=0;

  /**
   * Convenient operator overload to substract the vector by another.
   *
   * @param vec  The second vector to substract this vector with.
   */
  virtual void operator -=(const abstract_vector<T, S> &vec)=0;

  /**
   * Convenient operator overload to add a scalar to this vector (vector shift).
   *
   * @param c  The scalar to add.
   */
  virtual void operator +=(S c)=0;

  /**
   * Deep copy into this vector from a standard (CPU-based) vector.
   *
   * @param rhs  The vector to copy from.
   */
  virtual void operator =(const vector<S> &rhs)=0;

  /**
   * Deep copy into this vector from another abstract_vector.
   *
   * @param rhs  The vector to copy from.
   */
  virtual void operator=(const abstract_vector<T, S>& rhs)=0;

  /**
   * Shallow copy into this vector from another abstract_vector.
   *
   * I.e., copy the internal pointers only.
   *
   * @param v  The vector to copy from.
   */
  virtual void shallow_copy(const abstract_vector<T, S> &v)=0;

  /**
   * Deep copy into this vector from another abstract_vector.
   *
   * @param v  The vector to copy from.
   *
   * @TODO: unify with operator= ?
   */
  virtual void deep_copy(const abstract_vector<T, S> &v)=0;

  /**
   * Create a subvector which is defined on a superset of procs and has the same
   * layout
   *
   * Processes not part of the original owner set will have no data
   *
   * @param sub    the vector on the subnodes
   * @param member true if the process is part of the original vector
   * @param offset offset of new vector into original
   * @param sz     number of entries to extract from original, -1=all
   * @param share  use the same memory
   */
  virtual void overshadow(const abstract_vector<T, S> &sub,
                          bool member,
                          int offset,
                          int sz,
                          bool share)=0;

  /**
   * Get the local size.
   *
   * @returns the local size.
   */
  virtual T lsize() const=0;

  /**
   * Get the global size.
   *
   * @returns the global size.
   */
  virtual T gsize() const=0;

  /**
   * Get the range of indices owned by this processor.
   *
   * @param start  the first index owned.
   * @param stop   one more than the last index owned.
   */
  virtual void get_ownership_range(T &start, T &stop) const=0;

  /**
   * Get a host pointer to the local data. Use release_ptr when done.
   *
   * @returns a host pointer to the local data.
   *
   * @see release_ptr
   */
  virtual S *ptr()=0;

  /**
   * Get a const host pointer to the local data. Use const_release_ptr when
   * done.
   *
   * @returns a const host pointer to the local data.
   *
   * @see const_release_ptr
   */
  virtual const S *const_ptr() const=0;

  /**
   * Release a pointer to local data
   *
   * @param p  the pointer to release
   *
   * @see ptr
   */
  virtual void release_ptr(S *&p)=0;

  /**
   * Release a const pointer to local data
   *
   * @param p  the const pointer to release
   *
   * @see const_ptr
   */
  virtual void const_release_ptr(const S *&p) const=0;

  /**
   * Compute the L2 norm of this vector.
   *
   * @returns the L2 norm of this vector.
   */
  virtual S mag() const=0;

  /**
   * Compute the sum of elements of this vector.
   *
   * @returns the sum of elements of this vector.
   */
  virtual S sum() const=0;

  /**
   * Find the minimum value of this vector.
   *
   * @returns the minimum value of this vector.
   */
  virtual S min() const=0;

  /**
   * Compute the dot product of this vector and the vector v.
   *
   * @param v  The other vector used in the dot product.
   *
   * @returns  the dot product of this vector and the vector v.
   */
  virtual S dot(const abstract_vector<T, S> &v) const=0;

  /**
   * Whether the vector is initialized.
   *
   * @returns whether the vector is initialized.
   */
  virtual bool is_init() const=0;

  /**
   * A string format for the current vector.
   *
   * @returns a string format for the current vector.
   */
  virtual std::string to_string() const=0;

  /**
   * Whether the this vector and rhs are equal.
   *
   * @returns whether the this vector and rhs are equal.
   */
  virtual bool equals(const abstract_vector<T,S> &rhs) const=0;

  /**
   * Mark the assembly as finished.
   */
  virtual void finish_assembly()=0;

  /**
   * Forward scattering. This object is input (from).
   *
   * @param out  Scatter to.
   * @param sc   The scattering class.
   * @param add  Use additive scattering or overwrite.
   */
  virtual void forward(abstract_vector<T, S> &out,
                       scattering &sc,
                       bool add=false)=0;

  /**
   * Backward scattering. This object is input (from).
   *
   * @param out  Scatter to.
   * @param sc   The scattering class.
   * @param add  Use additive scattering or overwrite.
   */
  virtual void backward(abstract_vector<T,S> &out,
                        scattering &sc,
                        bool add=false)=0;

  /**
   * Apply the scattering sc to this vector.
   *
   * @param sc   The scattering class.
   * @param fwd  Use forward or backwdard scattering.
   */
  virtual void apply_scattering(scattering& sc, bool fwd)=0;

  /**
   * Write the vector to a file
   *
   * @param file          The file to write to.
   * @param write_header  Whether to write the header as well
   *
   * @returns the number of characters written.
   */
  inline size_t write_ascii(const char *file, bool write_header) {
    int size, rank;
    MPI_Comm comm=this->mesh!=NULL?this->mesh->comm:PETSC_COMM_WORLD;
    PetscCallMPI(MPI_Comm_rank(comm, &rank));
    PetscCallMPI(MPI_Comm_size(comm, &size));

    int glb_size=this->gsize();
    int loc_size=this->lsize();
    int err=0;
    FILE *fd=NULL;
    long int nwr=0;
    if(rank==0) {
      fd=fopen(file, "w");
      if(!fd) err=1;
    }
    PetscCallMPI(MPI_Allreduce(MPI_IN_PLACE,
                               &err, 1,
                               MPI_INT, MPI_MAX,
                               comm));
    if(err) {
      treat_file_open_error(file, __func__, errno, false, rank);
      return nwr;
    }
    S *p=this->ptr();
    if(rank==0) {
      if(write_header)
        fprintf(fd, "%d\n", glb_size);

      for(int i=0; i<loc_size/this->dpn; i++) {
        for(int j=0; j<this->dpn; j++)
          nwr+=fprintf(fd, "%f ", p[i*this->dpn+j]);
        nwr+=fprintf(fd, "\n");
      }
      vector<S> wbuff;
      for(int pid=1; pid<size; pid++) {
        int rsize;
        MPI_Status stat;
        PetscCallMPI(MPI_Recv(&rsize, 1,
                              MPI_INT, pid,
                              SF_MPITAG,
                              comm, &stat));
        wbuff.resize(rsize);
        PetscCallMPI(MPI_Recv(wbuff.data(), rsize*sizeof(S),
                              MPI_BYTE, pid,
                              SF_MPITAG,
                              comm, &stat));
        for(int i=0; i<rsize/this->dpn; i++) {
          for(int j=0; j<this->dpn; j++)
            nwr+=fprintf(fd, "%f ", wbuff[i*this->dpn+j]);
          nwr+=fprintf(fd, "\n");
        }
      }
      fclose(fd);
    } else {
      PetscCallMPI(MPI_Send(&loc_size, 1,
                            MPI_INT, 0,
                            SF_MPITAG,
                            comm));
      PetscCallMPI(MPI_Send(p, loc_size*sizeof(S),
                            MPI_BYTE, 0,
                            SF_MPITAG,
                            comm));
    }
    this->release_ptr(p);
    PetscCallMPI(MPI_Bcast(&nwr, 1, MPI_LONG, 0, comm));
    return nwr;
  }

  /**
  * @brief Write a vector to HD in binary. File descriptor is already set up.
  *
  * File descriptor is not closed by this function.
  *
  * @param fd   The already set up file descriptor.
  */
  template<typename V>
  inline size_t write_binary(FILE *fd) {
    int size, rank;
    MPI_Comm comm=this->mesh!=NULL?this->mesh->comm:PETSC_COMM_WORLD;
    PetscCallMPI(MPI_Comm_rank(comm, &rank));
    PetscCallMPI(MPI_Comm_size(comm, &size));
    long int loc_size=this->lsize();
    S* p=this->ptr();
    vector<V> buff(loc_size);
    for(long int i=0; i<loc_size; i++)
      buff[i]=p[i];
    long int nwr=root_write(fd, buff, comm);
    this->release_ptr(p);
    return nwr;
  }

  /// write binary. Open file descriptor myself.
  template<typename V>
  inline size_t write_binary(std::string file) {
    size_t nwr=0;
    MPI_Comm comm=this->mesh!=NULL?this->mesh->comm:PETSC_COMM_WORLD;
    int rank;
    PetscCallMPI(MPI_Comm_rank(comm, &rank));
    FILE *fd=NULL;
    int error=0;
    if(rank==0) {
      fd=fopen(file.c_str(), "w");
      if(fd==NULL)
        error++;
    }
    PetscCallMPI(MPI_Allreduce(MPI_IN_PLACE,
                               &error, 1,
                               MPI_INT,
                               MPI_SUM,
                               comm));
    if(error==0) {
      nwr=this->write_binary<V>(fd);
      fclose(fd);
    } else {
      treat_file_open_error(file.c_str(), __func__, errno, false, rank);
    }
    return nwr;
  }

  template<typename V>
  inline size_t read_binary(FILE *fd) {
    MPI_Comm comm=this->mesh!=NULL?this->mesh->comm:PETSC_COMM_WORLD;
    size_t loc_size=this->lsize();
    S* p=this->ptr();
    vector<V> buff(loc_size);
    size_t nrd=root_read(fd, buff, comm);
    for(size_t i=0; i<loc_size; i++)
      p[i]=buff[i];
    this->release_ptr(p);
    return nrd;
  }

  template<typename V>
  inline size_t read_binary(std::string file) {
    MPI_Comm comm=mesh!=NULL ? mesh->comm : PETSC_COMM_WORLD;
    size_t nrd=0;
    int rank;
    PetscCallMPI(MPI_Comm_rank(comm, &rank));
    FILE *fd=NULL;
    int error=0;
    if(rank==0) {
      fd=fopen(file.c_str(), "r");
      if(fd==NULL)
        error++;
    }
    PetscCallMPI(MPI_Allreduce(MPI_IN_PLACE,
                               &error, 1,
                               MPI_INT,
                               MPI_SUM,
                               comm));
    if(error==0) {
      nrd=read_binary<V>(fd);
      fclose(fd);
    } else {
      treat_file_open_error(file.c_str(), __func__, errno, false, rank);
    }
    return nrd;
  }

  inline size_t read_ascii(FILE *fd) {
    MPI_Comm comm=this->mesh!=NULL?this->mesh->comm:PETSC_COMM_WORLD;
    size_t loc_size=this->lsize();
    S* p=this->ptr();
    size_t nrd=root_read_ascii(fd, p, loc_size, comm, false);
    return nrd;
  }

  inline size_t read_ascii(std::string file) {
    MPI_Comm comm=this->mesh!=NULL?this->mesh->comm:PETSC_COMM_WORLD;
    int rank;
    PetscCallMPI(MPI_Comm_rank(comm, &rank));
    size_t nrd=0;
    FILE *fd=NULL;
    int error=0;
    if(rank==0) {
      fd=fopen(file.c_str(), "r");
      if(fd==NULL)
        error++;
    }
    PetscCallMPI(MPI_Allreduce(MPI_IN_PLACE,
                               &error, 1,
                               MPI_INT,
                               MPI_SUM,
                               comm));
    if(error==0) {
      nrd=read_ascii(fd);
      if(fd) fclose(fd);
    } else {
      treat_file_open_error(file.c_str(), __func__, errno, false, rank);
    }
    return nrd;
  }
};


/// check is v is initialized. since we have abstract vector pointers in the simulator
/// we need to first check for nullptr, then for v->is_init().
template<class T, class S>
inline bool is_init(const abstract_vector<T,S> *v) {
  return (v&&v->is_init());
}


// TODO: This is a type of Vector and can most likely be integrated into the
// `abstract_vector` type in some way. Everything here and also in
// `SF_parallel_layout.h` probably need to be abstracted away, or made less
// PETSc specific?
/**
* @brief Container for a PETSc VecScatter
*
*   A VecScatter redistributes vector data from indexing "a" to indexing "b".
*   Where the two indexings can have different parallel layouts.
*
*/
class scattering {
  public:
  Vec b_buff;  ///< A buffer vector which also defines the parallel layout of the "b" side.
  VecScatter vec_sc;  ///< The scatterer.

  vector<SF_int> idx_a, idx_b;

  /// Constructor
  scattering():b_buff(NULL), vec_sc(NULL) {}

  /// Destructor
  ~scattering() {
    if(b_buff)
      PetscCallVoid(VecDestroy(&b_buff));
    if(vec_sc)
      PetscCallVoid(VecScatterDestroy(&vec_sc));
  }
  /**
  * @brief Forward scattering
  *
  * @param in  Scatter from.
  * @param out Scatter to.
  */
  template<class T, class S>
  inline void forward(abstract_vector<T,S> &in,
                      abstract_vector<T,S> &out,
                      bool add=false) {
    in.forward(out, *this, add);
  }

  /**
  * @brief Backward scattering
  *
  * @param in  Scatter from.
  * @param out Scatter to.
  */
  template<class T, class S>
  inline void backward(abstract_vector<T,S> &in,
                       abstract_vector<T,S> &out,
                       bool add=false) {
    in.backward(out, *this, add);
  }

  /**
   * @brief Apply the scattering on a data vector
   *
   * @param [in, out] v    The data vector.
   * @param [in]      fwd  True for forward, false for backward scatting.
   */
  template<class T, class S>
  inline void operator()(abstract_vector<T,S> &v, bool fwd) {
    v.apply_scattering(*this, fwd);
  }
};

/**
* @brief The scatterer registry class.
*
* Scatterings between arbitrary numberings and parallel layouts can be
* registered for later access.
*
* @tparam T Integer type.
*/
template<class T>
class scatter_registry {
  private:
  /// the scattering registry
  hashmap::unordered_map<quadruple<int>, scattering*> _registry;

  public:
  /**
  * @brief Register a permutation scattering.
  *
  * @param [in] spec     The spec specifies: v1=mesh ID, v2=permutation type, v3=numbering, v4=dpn
  * @param [in] nbr_a    Nodal numbering of "a" side.
  * @param [in] nbr_b    Nodal numbering of "b" side.
  * @param [in] gsize_a  Global nodal size of "a" side.
  * @param [in] gsize_b  Global nodal size of "b" side.
  * @param [in] dpn      Degrees of freedom per node index.
  *
  * @post Scattering has been registered and set up.
  */
  inline
  scattering* register_permutation(const quadruple<int> spec,
                                   const vector<T> & nbr_a,
                                   const vector<T> & nbr_b,
                                   const size_t gsize_a,
                                   const size_t gsize_b,
                                   const short dpn) {
    assert(_registry.count(spec)==0);
    scattering *sc=new scattering();
    _registry[spec]=sc;
    IS is_a, is_b;
    //int err=0;
    vector<SF_int> idx_a(nbr_a.size() * dpn);
    vector<SF_int> idx_b(nbr_b.size() * dpn);
    // we copy indexing into new containers because of dpn and also
    // because of the implicit typecast between T and SF_int
    for(size_t i=0; i<nbr_a.size(); i++)
      for(short j=0; j<dpn; j++)
        idx_a[i*dpn+j]=nbr_a[i]*dpn+j;
    for(size_t i=0; i<nbr_b.size(); i++)
      for(short j=0; j<dpn; j++)
        idx_b[i*dpn+j]=nbr_b[i]*dpn+j;
    PetscCallAbort(PETSC_COMM_WORLD,
                   ISCreateGeneral(PETSC_COMM_WORLD,
                                   idx_a.size(), idx_a.data(),
                                   PETSC_COPY_VALUES,
                                   &is_a));
    PetscCallAbort(PETSC_COMM_WORLD,
                   ISCreateGeneral(PETSC_COMM_WORLD,
                                   idx_b.size(), idx_b.data(),
                                   PETSC_COPY_VALUES,
                                   &is_b));
    PetscCallAbort(PETSC_COMM_WORLD, ISSetPermutation(is_b));
    Vec a;
    PetscCallAbort(PETSC_COMM_WORLD,
                   VecCreateFromOptions(PETSC_COMM_WORLD,
                                        NULL, 1,
                                        idx_a.size(), gsize_a*dpn,
                                        &a));
    if(sc->b_buff)
      PetscCallAbort(PETSC_COMM_WORLD,
                     VecDestroy(&sc->b_buff));
    PetscCallAbort(PETSC_COMM_WORLD,
                   VecCreateFromOptions(PETSC_COMM_WORLD,
                                        NULL, 1,
                                        idx_b.size(), gsize_b*dpn,
                                        &sc->b_buff));
    PetscCallAbort(PETSC_COMM_WORLD,
                   VecScatterCreate(a, is_a,
                                    sc->b_buff, is_b,
                                    &sc->vec_sc));
    PetscCallAbort(PETSC_COMM_WORLD, VecDestroy(&a));
    PetscCallAbort(PETSC_COMM_WORLD, ISDestroy(&is_a));
    PetscCallAbort(PETSC_COMM_WORLD, ISDestroy(&is_b));
    //if(err)
      //fprintf(stderr, "%s : an error has occurred! Scattering spec: Mesh ID %d, permutation ID %d, numbering %d, dpn %d!\n",
              //__func__, int(spec.v1), int(spec.v2), int(spec.v3), int(spec.v4));
    sc->idx_a=idx_a;
    sc->idx_b=idx_b;
    return sc;
  }


  /**
  * @brief Register a scattering.
  *
  * @post Scattering has been registered and set up.
  */
  inline
  scattering *register_scattering(const quadruple<int> spec,
                                  const vector<T> & layout_a,
                                  const vector<T> & layout_b,
                                  const vector<T> & idx_a,
                                  const vector<T> & idx_b,
                                  const int rank,
                                  const int dpn) {
    // scattering spec must not exist yet
    assert(_registry.count(spec)==0);
    // the local index sets have to be of equal size.
    assert(idx_a.size()==idx_b.size());
    scattering *sc=new scattering();
    _registry[spec]=sc;
    IS is_a, is_b;
    //int err=0;
    vector<SF_int> sidx_a(idx_a.size() * dpn);
    vector<SF_int> sidx_b(idx_b.size() * dpn);
    T lsize_a=layout_a[rank+1] - layout_a[rank];
    T lsize_b=layout_b[rank+1] - layout_b[rank];
    T gsize_a=layout_a[layout_a.size()-1];
    T gsize_b=layout_b[layout_a.size()-1];
    // we copy indexing into new containers because of dpn and also
    // because of the implicit typecast between T and SF_int
    for(size_t i=0; i<idx_a.size(); i++)
      for(short j=0; j<dpn; j++)
        sidx_a[i*dpn+j]=idx_a[i]*dpn+j;

    for(size_t i=0; i<idx_b.size(); i++)
      for(short j=0; j<dpn; j++)
        sidx_b[i*dpn+j]=idx_b[i]*dpn+j;

    PetscCallAbort(PETSC_COMM_WORLD,
                   ISCreateGeneral(PETSC_COMM_WORLD,
                                   sidx_a.size(), sidx_a.data(),
                                   PETSC_COPY_VALUES,
                                   &is_a));
    PetscCallAbort(PETSC_COMM_WORLD,
                   ISCreateGeneral(PETSC_COMM_WORLD,
                                   sidx_b.size(), sidx_b.data(),
                                   PETSC_COPY_VALUES,
                                   &is_b));
    Vec a;
    PetscCallAbort(PETSC_COMM_WORLD,
                   VecCreateFromOptions(PETSC_COMM_WORLD,
                                        NULL, 1,
                                        lsize_a*dpn, gsize_a*dpn,
                                        &a));
    if(sc->b_buff)
      PetscCallAbort(PETSC_COMM_WORLD,
                     VecDestroy(&sc->b_buff));
    PetscCallAbort(PETSC_COMM_WORLD,
                   VecCreateFromOptions(PETSC_COMM_WORLD,
                                        NULL, 1,
                                        lsize_b*dpn, gsize_b*dpn,
                                        &sc->b_buff));
    PetscCallAbort(PETSC_COMM_WORLD,
                   VecScatterCreate(a, is_a,
                                    sc->b_buff, is_b,
                                    &sc->vec_sc));
    PetscCallAbort(PETSC_COMM_WORLD, VecDestroy(&a));
    PetscCallAbort(PETSC_COMM_WORLD, ISDestroy (&is_a));
    PetscCallAbort(PETSC_COMM_WORLD, ISDestroy (&is_b));
    //if(err)
      //fprintf(stderr, "%s : an error has occurred! Scattering spec: To ID %d, From ID %d, numbering %d, dpn %d!\n",
              //__func__, int(spec.v1), int(spec.v2), int(spec.v3), int(spec.v4));
    sc->idx_a=idx_a;
    sc->idx_b=idx_b;
    return sc;
  }

  /**
  * @brief Access an previously registered scattering.
  *
  * @param [in]  spec         Scattering specification, see register routines.
  * @param [out] use_forward  If the scattering was found, this is true. If only the
  *                           transposed scattering was found this is false and the
  *                           returned scattering has to be used transposed.
  *
  * @return The requested scattering.
  */
  inline scattering* get_scattering(const quadruple<int> spec) {
    scattering *ret=NULL;
    // scattering must be present
    if(_registry.count(spec))
      ret=_registry[spec];
    return ret;
  }

  /**
  * @brief Free the registered scatterings.
  */
  inline void free_scatterings() {
    typename hashmap::unordered_map<quadruple<int>,
                                    scattering*>::iterator it;
    for(it=_registry.begin(); it!=_registry.end(); ++it) {
      if(it->second) {
        delete it->second;
        it->second=NULL;
      }
    }
  }
};


} // namespace SF


#endif // _SF_ABSTRACT_VECTOR_H
