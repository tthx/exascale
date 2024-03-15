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

/**
* @file petsc_utils.cc
* @brief Basic PETSc utilities.
* @author Gernot Plank, Edward Vigmond
* @version
* @date 2019-10-25
*/

#include "petsc_utils.h"
#include "basics.h"

namespace opencarp {

void initialize_PETSc(int *argc, char **argv, char *rc, char *help_msg) {
  // find indicator of PETSc options
  int PetOptInd=*argc;
  for(int i=0; i<*argc; i++) {
    if(strcmp(argv[i], DELIMIT_OPTS)==0) {
      PetOptInd=i;
      break;
    }
  }
  int numPetOpt=*argc-PetOptInd;
  *argc=PetOptInd;
  if(numPetOpt==0)
    numPetOpt=1; // for argv[0]
  char **petArg=(char**)malloc((numPetOpt)*sizeof(char*));
  petArg[0]=dupstr(argv[0]);
  for(int i=1; i<numPetOpt; i++)
    petArg[i]=dupstr(argv[PetOptInd+i]);
  // only PETSc specific options are provided to PetscInitialize
  PetscCallVoid(PetscInitialize(&numPetOpt, &petArg, rc, help_msg));
  for(int i=0; i<numPetOpt; i++)
    free(petArg[i]);
  free(petArg);
}

char *Petscgetline(FILE *f) {
  size_t size=0;
  size_t len=0;
  size_t last=0;
  char *buf=PETSC_NULLPTR;
  if(feof(f))
    return 0;
  do {
    size+=1024; /* BUFSIZ is defined as "the optimal read size for this platform" */
    buf=(char*)realloc((void*)buf, size); /* realloc(NULL,n) is the same as malloc(n) */
    /* Actually do the read. Note that fgets puts a terminal '\0' on the
    end of the string, so we make sure we overwrite this */
    if(!fgets(buf+len, size, f))
      buf[len]=0;
    PetscCallAbort(PETSC_COMM_WORLD, PetscStrlen(buf, &len));
    last=len-1;
  } while((!feof(f)) &&
          (buf[last]!='\n') &&
          (buf[last]!='\r'));
  if(len)
    return buf;
  free(buf);
  return 0;
}

PetscErrorCode PetscOptionsClearFromString(const char in_str[]) {
  char *first, *second;
  PetscToken token;
  PetscBool key;
  PetscFunctionBeginUser;
  PetscCall(PetscTokenCreate(in_str, ' ', &token));
  PetscCall(PetscTokenFind(token, &first));
  while(first) {
    PetscCall(PetscOptionsValidKey(first, &key));
    if(key) {
      PetscCall(PetscTokenFind(token, &second));
      PetscCall(PetscOptionsValidKey(second, &key));
      if(!key) {
        PetscCall(PetscOptionsClearValue(PETSC_NULLPTR, first));
        PetscCall(PetscTokenFind(token, &first));
      } else {
        PetscCall(PetscOptionsClearValue(PETSC_NULLPTR, first));
        first=second;
      }
    } else {
      PetscCall(PetscTokenFind(token, &first));
    }
  }
  PetscCall(PetscTokenDestroy(&token));
  PetscFunctionReturn(PETSC_SUCCESS);
}


PetscErrorCode PetscOptionsClearFromFile(MPI_Comm comm, const char *file) {
  char *string,
    fname[PETSC_MAX_PATH_LEN],
    *first,
    *second,
    *third,
    *vstring=0,
    *astring=0;
  size_t i,len;
  FILE *fd;
  PetscToken token;
  int err;
  char cmt[3]={'#','!','%'}, *cmatch;
  PetscMPIInt rank, cnt=0, acnt=0;

  PetscFunctionBeginUser;
  PetscCallMPI(MPI_Comm_rank(comm, &rank));
  if(!rank) {
    /* Warning: assume a maximum size for all options in a string */
    PetscCall(PetscMalloc(128000*sizeof(char), &vstring));
    vstring[0]=0;
    PetscCall(PetscMalloc(64000*sizeof(char), &astring));
    astring[0]=0;
    cnt=0;
    acnt=0;

    PetscCall(PetscFixFilename(file, fname));
    fd=fopen(fname, "r");
    if(fd) {
      while((string=Petscgetline(fd))) {
        /* eliminate comments from each line */
        for(i=0; i<3; i++) {
          PetscCall(PetscStrchr(string, cmt[i], &cmatch));
          if(cmatch)
            *cmatch=0;
        }
        PetscCall(PetscStrlen(string, &len));
        /* replace tabs, ^M, \n with " " */
        for(i=0; i<len; i++) {
          if((string[i]=='\t') ||
             (string[i]=='\r') ||
             (string[i]=='\n')) {
            string[i]=' ';
          }
        }
        PetscCall(PetscTokenCreate(string, ' ', &token));

        // temporary fix, do not remove mat_pastix_* options
        void *pastix_check=strstr(string, "-mat_pastix_check");
        void *pastix_verbose=strstr(string, "-mat_pastix_verbose");
        if((pastix_check) ||
           (pastix_verbose)) {
          strcpy(string, "-ignore 0");
          PetscCall(PetscTokenCreate(string, ' ', &token));
        }
        PetscCall(PetscTokenFind(token, &first));

        if(!first) {
          goto destroy;
        } else if(!first[0]) { /* if first token is empty spaces, redo first token */
          PetscCall(PetscTokenFind(token, &first));
        }
        PetscCall(PetscTokenFind(token, &second));
        if(!first) {
          goto destroy;
        }
        else if(first[0]=='-') {
          /* warning: should be making sure we do not overfill vstring */
          PetscCall(PetscStrcat(vstring, first));
          PetscCall(PetscStrcat(vstring, " "));
          if (second) {
            /* protect second with quotes in case it contains strings */
            PetscCall(PetscStrcat(vstring, "\""));
            PetscCall(PetscStrcat(vstring, second));
            PetscCall(PetscStrcat(vstring, "\""));
          }
          PetscCall(PetscStrcat(vstring, " "));
        } else {
          PetscBool match;

          PetscCall(PetscStrcasecmp(first, "alias", &match));
          if(match) {
            PetscCall(PetscTokenFind(token, &third));
            if (!third) SETERRQ(comm, PETSC_ERR_ARG_WRONG, "Error in options file:alias missing (%s)", second);
            PetscCall(PetscStrcat(astring, second));
            PetscCall(PetscStrcat(astring, " "));
            PetscCall(PetscStrcat(astring, third));
            PetscCall(PetscStrcat(astring, " "));
          } else {
            SETERRQ(comm, PETSC_ERR_ARG_WRONG, "Unknown statement in options file: (%s)", string);
          }
        }
destroy:
        free(string);
        PetscCall(PetscTokenDestroy(&token));
      }

      err=fclose(fd);
      if(err)
        SETERRQ(comm, PETSC_ERR_SYS, "fclose() failed on file");
      PetscCall(PetscStrlen(astring, &len));
      PetscCall(PetscMPIIntCast(len, &acnt));
      PetscCall(PetscStrlen(vstring, &len));
      PetscCall(PetscMPIIntCast(len, &cnt));
    }
  }

  PetscCallMPI(MPI_Bcast(&acnt, 1, MPIU_INT, 0, comm));
  if(acnt) {
    //PetscToken token;
    //char *first,*second;
    if(rank) {
      PetscCall(PetscMalloc((acnt+1)*sizeof(char), &astring));
    }
    PetscCallMPI(MPI_Bcast(astring, acnt, MPI_CHAR, 0, comm));
    astring[acnt]=0;
    PetscCall(PetscTokenCreate(astring, ' ', &token));
    PetscCall(PetscTokenFind(token, &first));
    while(first) {
      PetscCall(PetscTokenFind(token, &second));
      PetscCall(PetscOptionsSetAlias(PETSC_NULLPTR, first, second));
      PetscCall(PetscTokenFind(token, &first));
    }
    PetscCall(PetscTokenDestroy(&token));
  }

  PetscCallMPI(MPI_Bcast(&cnt, 1, MPIU_INT, 0, comm));
  if(cnt) {
    if(rank) {
      PetscCall(PetscMalloc((cnt+1)*sizeof(char), &vstring));
    }
    PetscCallMPI(MPI_Bcast(vstring, cnt, MPI_CHAR, 0, comm));
    vstring[cnt]=0;
    PetscCall(PetscOptionsClearFromString(vstring));
  }
  PetscCall(PetscFree(astring));
  PetscCall(PetscFree(vstring));
  PetscFunctionReturn(PETSC_SUCCESS);
}

const char *petsc_get_converged_reason_str(int reason) {
  const char *ret="";
  switch(reason) {
    case  0  : ret="iterating"; break;
    case  1  : ret="relative tolerance normal"; break;
    case  2  : ret="relative tolerance"; break;
    case  3  : ret="absolute tolerance"; break;
    case  4  : ret="iterations"; break;
    case  5  : ret="cg neg curve"; break;
    case  6  : ret="cg constrained"; break;
    case  7  : ret="step length"; break;
    case  8  : ret="happy breakdown"; break;
    case  9  : ret="atol normal"; break;
    case -2  : ret="null error"; break;
    case -3  : ret="iterations exceeded"; break;
    case -4  : ret="tolerance failed"; break;
    case -5  : ret="breakdown"; break;
    case -6  : ret="breakdown bicg"; break;
    case -7  : ret="nonsymmetric where symmetry required"; break;
    case -8  : ret="indefinite preconditioning"; break;
    case -9  : ret="NaN or inf encountered"; break;
    case -10 : ret="indefinite system matrix"; break;
    case -11 : ret="preconditioning failed"; break;
    default: ret="unknown";
  }
  return ret;
}

}  // namespace opencarp

