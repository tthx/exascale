#ifndef _SF_PETSC_VECTOR_H
#define _SF_PETSC_VECTOR_H

#include "SF_abstract_vector.h"

#ifdef WITH_PETSC

#include <petscvec.h>

#include "SF_globals.h"


namespace SF {


// A few helpers
inline void petsc_forward(Vec in, Vec out, scattering &sc, bool add=false) {
  InsertMode imode=add?ADD_VALUES:INSERT_VALUES;
  PetscCallVoid(VecScatterBegin(sc.vec_sc, in, out, imode, SCATTER_FORWARD));
  PetscCallVoid(VecScatterEnd(sc.vec_sc, in, out, imode, SCATTER_FORWARD));
}

inline void petsc_backward(Vec in, Vec out, scattering &sc, bool add=false) {
  InsertMode imode=add?ADD_VALUES:INSERT_VALUES;
  PetscCallVoid(VecScatterBegin(sc.vec_sc, in, out, imode, SCATTER_REVERSE));
  PetscCallVoid(VecScatterEnd(sc.vec_sc, in, out, imode, SCATTER_REVERSE));
}

/**
 * @brief A class encapsulating a PETSc vector.
 *
 * @note Objects of this class should not be used or initialized directly.
 *       Instead, use virtual functions on the abstract_vector base type and
 *       use the init_vector() functions from numerics/SF_init.h.
 *
 * @see abstract_vector
 * @see numerics/SF_init.h
 */
template<class T, class S>
class petsc_vector:public abstract_vector<T,S> {

  using typename abstract_vector<T,S>::ltype;

  public:

  Vec data=PETSC_NULLPTR; // the PETSc vector pointer

  petsc_vector() {}

  ~petsc_vector() override {
    if(this->data)
      PetscCallVoid(VecDestroy(&this->data));
  }

  petsc_vector(const meshdata<mesh_int_t,mesh_real_t> &imesh,
               int idpn, ltype inp_layout) {
    init(imesh, idpn, inp_layout);
  }

  petsc_vector(int igsize, int ilsize, int idpn, ltype ilayout) {
    init(igsize, ilsize, idpn, ilayout);
  }

  petsc_vector(const petsc_vector<T,S> & vec) {
    init(vec);
  }

  inline void init(const meshdata<mesh_int_t,mesh_real_t> &imesh,
                   int idpn, ltype inp_layout) override {
    PetscInt N=0, n=0;
    std::tie(N, n)=abstract_vector<T,S>::init_common(imesh, idpn, inp_layout);
    if(this->data)
      PetscCallVoid(VecDestroy(&this->data));
    PetscCallVoid(VecCreateMPICUDA(PETSC_COMM_WORLD, n, N, &this->data));
  }

  inline void init(int igsize, int ilsize, int idpn=1,
                   ltype ilayout=abstract_vector<T,S>::unset) override {
    if(this->data)
      PetscCallVoid(VecDestroy(&this->data));
    if((ilsize==igsize) && (igsize>=0)) {
      PetscCallVoid(VecCreateSeqCUDA(PETSC_COMM_SELF, igsize, &this->data));
    } else if(ilsize>=0) {
      PetscCallVoid(VecCreateMPICUDA(PETSC_COMM_WORLD,
                                     ilsize, abs(igsize), &this->data));
    } else {
      PetscCallVoid(VecCreateMPICUDA(PETSC_COMM_WORLD,
                                     PETSC_DECIDE, abs(igsize), &this->data));
    }
    PetscCallVoid(VecSet(this->data, 0.0));
    this->mesh=NULL;
    this->dpn=idpn;
    this->layout=ilayout;
  }

  inline void init(const abstract_vector<T,S> &vec_) override {
    auto &vec=dynamic_cast<const petsc_vector<T,S> &>(vec_);
    if(this->data)
      PetscCallVoid(VecDestroy(&this->data));
    PetscCallVoid(VecDuplicate(vec.data, &this->data));
    PetscCallVoid(VecSet(this->data, 0.0));
    this->mesh=vec.mesh;
    this->dpn=vec.dpn;
    this->layout=vec.layout;
  }

  inline void set(const vector<T> &idx, const vector<S> &vals,
                  const bool additive=false) override {
    InsertMode mode=additive?ADD_VALUES:INSERT_VALUES;
    PetscCallVoid(VecSetValues(this->data,
                               idx.size(), idx.data(),
                               vals.data(), mode));
    PetscCallVoid(VecAssemblyBegin(this->data));
    PetscCallVoid(VecAssemblyEnd(this->data));
  }

  inline void set(const vector<T> &idx, const S val) override {
    vector<S> vals(idx.size(), val);
    this->set(idx, vals);
  }

  inline void set(const S val) override {
    PetscCallVoid(VecSet(this->data, val));
  }

  // TODO: This is very slow and should be removed
  inline void set(const T idx, const S val) override {
    PetscCallVoid(VecSetValue(this->data, idx, val, INSERT_VALUES));
    PetscCallVoid(VecAssemblyBegin(this->data));
    PetscCallVoid(VecAssemblyEnd(this->data));
  }

  // TODO: This is very slow and should be removed.
  // According to docs, out is only written on the processes holding the respecitve indices.
  inline void get(const vector<T> &idx, S *out) override {
    PetscCallVoid(VecGetValues(this->data, idx.size(), idx.data(), out));
  }

  // TODO: This is unreasonable
  S get(const T idx) override {
    S out;
    PetscCallAbort(PETSC_COMM_WORLD, VecGetValues(this->data, 1, &idx, &out));
    return out;
  }

  inline void operator *=(const S sca) override {
    PetscCallVoid(VecScale(this->data, sca));
  }

  inline void operator /=(const S sca) override {
    PetscCallVoid(VecScale(this->data, 1.0/sca));
  }

  inline void operator *=(const abstract_vector<T,S> &vec_) override {
    auto &vec=dynamic_cast<const petsc_vector<T,S> &>(vec_);
    PetscCallVoid(VecPointwiseMult(this->data, this->data, vec.data));
  }

  inline void add_scaled(const abstract_vector<T,S> &vec_, S k) override {
    auto &vec=dynamic_cast<const petsc_vector<T,S> &>(vec_);
    PetscCallVoid(VecAXPY(this->data, k, vec.data));
  }

  inline void operator +=(const abstract_vector<T,S> &vec_) override {
    auto &vec=dynamic_cast<const petsc_vector<T,S> &>(vec_);
    PetscCallVoid(VecAXPY(this->data, 1.0, vec.data));
  }

  inline void operator -=(const abstract_vector<T,S> &vec_) override {
    auto &vec=dynamic_cast<const petsc_vector<T,S> &>(vec_);
    PetscCallVoid(VecAXPY(this->data, -1.0, vec.data));
  }

  inline void operator +=(S c) override {
    PetscCallVoid(VecShift(this->data, c));
  }

  inline void operator =(const vector<S> &rhs) override {
    vector<T> idx(rhs.size());
    for(size_t i=0; i<idx.size(); i++)
      idx[i]=i;
    this->set(idx, rhs);
  }

  inline void operator =(const abstract_vector<T, S> &rhs) override {
    auto &v=dynamic_cast<const petsc_vector<T,S> &>(rhs);
    this->deep_copy(rhs);
  }

  inline void shallow_copy(const abstract_vector<T, S> &v_) override {
    auto &v=dynamic_cast<const petsc_vector<T,S> &>(v_);
    this->data=v.data;
    this->mesh=v.mesh;
    this->dpn=v.dpn;
    this->layout=v.layout;
  }

  inline void deep_copy(const abstract_vector<T,S> &vec_) override {
    auto &vec=dynamic_cast<const petsc_vector<T,S> &>(vec_);
    if(this->data)
      PetscCallVoid(VecDestroy(&this->data));
    PetscCallVoid(VecDuplicate(vec.data, &this->data));
    PetscCallVoid(VecCopy(vec.data, this->data));
    this->mesh=vec.mesh;
    this->dpn=vec.dpn;
    this->layout=vec.layout;
  }

  inline void overshadow(const abstract_vector<T,S> &sub_, bool member,
                         int offset, int sz, bool share) override {
    auto &sub=dynamic_cast<const petsc_vector<T,S> &>(sub_);
    // RVector super;
    int loc_size=0;
    const S *databuff=NULL;
    if(member) {
      T start, stop;
      sub.get_ownership_range(start, stop);
      if(sz==-1)
        sz = sub.gsize();
      T end=offset+sz;
      T lstart=stop-start;
      if(start>=offset)
        lstart=0;
      else if(offset<end)
        lstart=offset-start;
      int lstop=0;
      if(end>=stop)
        lstop=stop-start;
      else if(end>=start)
        lstop=end-start;
      loc_size=lstop-lstart;
      if(loc_size<0)
        loc_size=0;
      databuff=sub.const_ptr()+lstart;
    }
    if(this->data)
      PetscCallVoid(VecDestroy(&this->data));
    if(share)
      PetscCallVoid(VecCreateMPICUDAWithArray(PETSC_COMM_WORLD,
                                              1, loc_size,
                                              PETSC_DECIDE, databuff,
                                              &this->data));
    else
      PetscCallVoid(VecCreateMPICUDA(PETSC_COMM_WORLD,
                                     loc_size, PETSC_DECIDE,
                                     &this->data));
    if(member)
      sub.const_release_ptr(databuff);
  }

  inline T lsize() const override {
    T loc_size;
    PetscCallAbort(PETSC_COMM_WORLD, VecGetLocalSize(this->data, &loc_size));
    return loc_size;
  }

  inline T gsize() const override {
    T glb_size;
    PetscCallAbort(PETSC_COMM_WORLD, VecGetSize(this->data, &glb_size));
    return glb_size;
  }

  inline void get_ownership_range(T &start, T &stop) const override  {
    PetscCallVoid(VecGetOwnershipRange(this->data, &start, &stop));
  }

  inline S *ptr() override {
    S *p;
    // get pointer to local data
    PetscCallAbort(PETSC_COMM_WORLD, VecGetArray(this->data, &p));
    return p;
  }

  inline const S *const_ptr() const override {
    const S *p;
    // get read pointer to local data
    PetscCallAbort(PETSC_COMM_WORLD, VecGetArrayRead(this->data, &p));
    return p;
  }

  inline void release_ptr(S *&p) override {
    // release local data
    PetscCallVoid(VecRestoreArray(this->data, &p));
  }

  inline void const_release_ptr(const S *&p) const override {
    // release local read data
    PetscCallVoid(VecRestoreArrayRead(this->data, &p));
  }

  inline S mag() const override {
    S ret;
    PetscCallAbort(PETSC_COMM_WORLD, VecNorm(this->data, NORM_2, &ret));
    return ret;
  }

  inline S sum() const override {
    S ret;
    PetscCallAbort(PETSC_COMM_WORLD, VecSum(this->data, &ret));
    return ret;
  }

  inline S dot(const abstract_vector<T,S> & v_) const override {
    auto &v=dynamic_cast<const petsc_vector<T,S> &>(v_);
    S ret;
    PetscCallAbort(PETSC_COMM_WORLD, VecDot(this->data, v.data, &ret));
    return ret;
  }

  inline S min() const override {
    S min;
    PetscCallAbort(PETSC_COMM_WORLD, VecMin(this->data, NULL, &min));
    return min;
  }

  bool is_init() const override {
    return this->data!=PETSC_NULLPTR;
  }

  inline std::string to_string() const override {
    std::string result="petsc_vector (" + std::to_string(lsize()) + ") [";
    auto p=this->const_ptr();
    for(auto i=0; i<this->lsize(); i++) {
      if(i>0)
        result+=", ";
      result+=std::to_string(p[i]);
    }
    result+="]";
    this->const_release_ptr(p);
    return result;
  }

  inline bool equals(const abstract_vector<T,S> &rhs_) const override {
    auto &rhs=dynamic_cast<const petsc_vector<T,S> &>(rhs_);
    Vec diff;
    PetscInt size, rhs_size;
    S diff_max;
    if(this->data==rhs.data)
      return true;
    PetscCall(VecGetSize(this->data, &size));
    PetscCall(VecGetSize(rhs.data, &rhs_size));
    if(size!=rhs_size)
      return false;
    PetscCall(VecDuplicate(this->data, &diff));
    PetscCall(VecCopy(this->data, diff));
    PetscCall(VecAXPY(diff, -1.0, rhs.data));
    PetscCall(VecMax(diff, PETSC_NULLPTR, &diff_max));
    return abs(diff_max)<=0.0001;
  }

  inline void finish_assembly() override {
    PetscCallVoid(VecAssemblyBegin(this->data));
    PetscCallVoid(VecAssemblyEnd(this->data));
  }

  inline void forward(abstract_vector<T,S> &out_, scattering &sc,
                      bool add=false) override {
    auto &out=dynamic_cast<petsc_vector<T,S> &>(out_);
    petsc_forward(this->data, out.data, sc, add);
  }

  inline void backward(abstract_vector<T,S> &out_, scattering &sc,
                       bool add=false) override {
    auto &out=dynamic_cast<petsc_vector<T,S> &>(out_);
    petsc_backward(this->data, out.data, sc, add);
  }

  inline void apply_scattering(scattering &sc, bool fwd) override {
    if(fwd) {
      // in the case of forward mapping, the values are permuted from v into
      // b_buff.
      // We need to copy them out afterwards to guarantee consistency
      petsc_forward(this->data, sc.b_buff, sc);
      if(this->data)
        PetscCallVoid(VecDestroy(&this->data));
      PetscCallVoid(VecDuplicate(sc.b_buff, &this->data));
      PetscCallVoid(VecCopy(sc.b_buff, this->data));
    } else {
      // in the case of reverse mapping, the values are permuted from
      // sc.b_buff to v
      // We need to copy the values of v to pVec beforehand.
      if(sc.b_buff)
        PetscCallVoid(VecDestroy(&sc.b_buff));
      PetscCallVoid(VecDuplicate(this->data, &sc.b_buff));
      PetscCallVoid(VecCopy(this->data, sc.b_buff));
      petsc_backward(sc.b_buff, this->data, sc);
    }
  }
};

template<class T, class S>
void init_vector_petsc(abstract_vector<T,S>** vec);

} // namespace SF

#endif // WITH_PETSC
#endif // _SF_PETSC_VECTOR_H
