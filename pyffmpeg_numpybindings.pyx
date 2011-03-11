import numpy
import sys

cimport numpy as np
cdef extern from "numpy/arrayobject.h":
    void *PyArray_DATA(np.ndarray arr)


cdef extern from "Python.h":
    ctypedef int size_t
    object PyBuffer_FromMemory( void *ptr, int size)
    object PyBuffer_FromReadWriteMemory( void *ptr, int size)
    object PyString_FromStringAndSize(char *s, int len)
    void* PyMem_Malloc( size_t n)
    void PyMem_Free( void *p)


def rwbuffer_at(pos,len):
    cdef unsigned long ptr=<unsigned long>(pos)
    return PyBuffer_FromReadWriteMemory(<void *>ptr,len)

def numpyarr_at(pos,len,shape,dtype):
   return numpy.ndarray(shape=shape,dtype=dtype,buffer=rwbuffer_at(pos,len))

def PyArray_DATA_content_buffer(array):
  return PyBuffer_FromReadWriteMemory(PyArray_DATA(array),array.nbytes)

def PyArray_DATA_content(array):
  return <unsigned long long>PyArray_DATA(array)#,array.nbytes
