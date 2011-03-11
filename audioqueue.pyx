import numpy
import threading
import sys
cimport numpy as np
cdef extern from "numpy/arrayobject.h":
    void *PyArray_DATA(np.ndarray arr)


class Queue_Empty(Exception):
    pass

class Queue_Full(Exception):
    pass


cdef class AudioQueue:
    """
    This class is responsible for gathering sound sample together
    and if necessary, for reemitting new audio-packet of a specified size
    """
    cdef int limitsz
    cdef object l
    cdef unsigned long long _off # global time offset
    cdef unsigned long long _totallen # len of buffer
    cdef long long _newframepos # new frame starts at...
    cdef int _destframesize
    cdef int _destframeinterval
    cdef int _destframeoverlap
    cdef object _destframequeue
    cdef float tps
    cdef float samplerate
    cdef float speedrate[2]
    cdef object mutex
    def  __init__(self,limitsz=-1,samplerate=44100,tps=1000,destframesize=0, destframeoverlap=0,destframequeue=None):
        self.limitsz=limitsz
        self.l=[]
        self._off=0
        self._totallen=0
        self._newframepos=0
        self._destframesize=destframesize
        self._destframeoverlap=destframeoverlap
        self._destframeinterval=destframesize-destframeoverlap
        #print destframesize,destframeoverlap
        assert((self._destframeinterval>0) or destframesize==0)
        self._destframequeue=destframequeue
        self.tps=tps
        self.samplerate=samplerate
        self.speedrate[0]=tps/samplerate
        self.speedrate[1]=1./samplerate # how much seconds does elapse per sample
        self.mutex=threading.Lock()
    def __len__(self):
      """ return the current amount of audio in the queue"""
      return self._totallen
    def get_len(self):
        """ return the max amount of audio in the queue """
        return self.limitsz
    def get(self,wait=True):
        if (self.mutex.acquire(wait)):
            try:
                r= self.l.pop(0)
                self._totallen-=r[0].shape[0]
                self._newframepos-=r[0].shape[0]
                self._off+=r[0].shape[0]
                if (self._newframepos<0):
                    self._newframepos=0
                if (self._totallen<0):
                    self._totallen=0
                assert(self._newframepos>=0)
                assert(self._newframepos<=self._totallen)
                self.mutex.release()
                return r;
            except:
                self.mutex.release()
                raise Queue_Empty
        else:
            raise Queue_Empty
    def _timeat(self,x,t=0):
        i=0
        lli=self.l[i][0].shape[0]
        while (x>lli):
            x-=lli
            i+=1
            lli=self.l[i][0].shape[0]
        #print "erroneous  speedrate to correct"
        return self.l[i][1+t]+x*self.speedrate[t]
    def _check_push_frame(self,writesz):
                # we are already mutex protected here
            #print "dfsz=", self._destframesize,  self._totallen,  self._newframepos
        if (self._destframesize):
            #newframes=((self._totallen-self._newframepos)//(self._destframeinterval))-((self._totallen-(writesz+self._newframepos))//(self._destframeinterval))
            #newframes-=(self._destframeoverlap/self._destframeinterval)
            #print "# NEWFRAMES, TL, NFP",newframes,  self._totallen, self._newframepos
            while ((self._totallen-self._newframepos) > self._destframesize):
                    # we can add frames
                #print "#  TL, NFP,INT",  self._totallen, self._newframepos,self._destframeinterval
                #print  ((self._totallen+writesz-self._newframepos) , self._destframesize)
                #print self._destframequeue.get_len()
                #raise Exception,"Will lockx"
                #sys.stderr.write( "PUSHING...\n")
                #sys.stderr.write(str(self))
                #sys.stderr.write(str(self._destframequeue))
#                sys.stderr.write(str(self.mutex))
#                sys.stderr.write(str(self._destframequeue.mutex))
                self._destframequeue.putforce((self.__getslice(self._newframepos,(self._newframepos+self._destframesize)),self._timeat(self._newframepos),self._timeat(self._newframepos,t=1) ))
                #print "#  TL, NFP",  self._totallen, self._newframepos
                self._newframepos+=self._destframeinterval
                #print "#  TL, NFP",  self._totallen, self._newframepos
                #sys.stderr.write(str((self._newframepos, self._totallen)))
                assert(self._newframepos>=0)
                assert(self._newframepos<=self._totallen)
    def put(self,it,wait=True):
        if (self.mutex.acquire(wait)):
            if ((self.limitsz!=-1) and (len(self.l)>=self.limitsz)):
                self.mutex.release()
                raise Queue_Full
            self.l.append(it)
            self._totallen+=it[0].shape[0]
            self._check_push_frame(it[0].shape[0])
            self.mutex.release()
        else:
            raise Queue_Full
    def putforce(self,it,wait=True):
        #print self._newframepos, self.l, self.limitsz
        if (self.mutex.acquire(wait)):
            #print (self.limitsz==-1) or ((self.limitsz!=-1) and (len(self.l)<=self.limitsz))
            if ((self.limitsz!=-1) and (len(self.l)>=self.limitsz)):
                #sys.stderr.write("warning : audio queue overloaded\n")
                x=self.l.pop(0)
                #print "$",   self._totallen, self._newframepos
                self._totallen-=x[0].shape[0]
                self._newframepos-=x[0].shape[0]
                self._off+=x[0].shape[0]
                #print "$",   self._totallen, self._newframepos
                if (self._newframepos<0):
                    self._newframepos=0
                if (self._totallen<0):
                    self._totallen=0
                assert(self._newframepos>=0)
                assert(self._newframepos<=self._totallen)
            self.l.append(it)
            self._totallen+=it[0].shape[0]
            self._check_push_frame(it[0].shape[0])
            self.mutex.release()
    def get_nowait(self):
        return self.get(wait=False)
    def put_nowait(self,it):
        return self.put(it,wait=False)
    def putforce_nowait(self,it):
        return self.putforce(it,wait=False)
    def __getitem__(self,x):
        # 0  is the fist element in the non popped array so we start from last buf
        assert(x>=0)
        self.mutex.acquire()
        if (x>=self._totallen):
            self.mutex.release()
            assert(x<self._totallen)
            assert(False)
        i=0#i=-1
        try:
            lli=self.l[i][0].shape[0]
        except:
            self.mutex.release()
            raise IndexError
        while (x>lli):
            x-=lli
            i+=1#i-=1
            try:
                lli=self.l[i][0].shape[0]
            except:
                self.mutex.release()
                raise IndexError
        r=self.l[i][0][x]
        self.mutex.release()
        return r
    def __getslice__(self,x,y):
        # 0  is the fist element in the non popped array so we start from last buf
        assert(y>=x)
        assert(x>=0)
        self.mutex.acquire()
        if (y>self._totallen):
            self.mutex.release()
            assert(y<=self._totallen)
            assert(False)
        if (y==x):
            self.mutex.release()
            return []
        i=0#i=-1
        try:
            lli=self.l[i][0].shape[0]
        except:
            self.mutex.release()
            raise IndexError
        while (x>=lli):
            x-=lli
            y-=lli
            #i-=1
            i+=1
            try:
                lli=self.l[i][0].shape[0]
            except:
                self.mutex.release()
                raise IndexError
        j=i
        llj=lli
        while (y>llj):
            y-=llj
            #j-=1
            j+=1
            try:
                llj=self.l[j][0].shape[0]
            except:
                self.mutex.release()
                raise IndexError
        if (i==j):
            try:
                r=self.l[i][0][x:y]
            except:
                self.mutex.release()
                raise IndexError
            self.mutex.release()
            return r
        else:
            #range (i-1,j,-1)
            try:
                r=numpy.vstack( [ self.l[i][0][x:,:] ]  + [ self.l[k][0] for k in range (i+1,j) ]  +   [ self.l[j][0][:y,:] ])
            except:
                self.mutex.release()
                raise IndexError
            self.mutex.release()
            return r
    def __getitem(self,x):
        # 0  is the fist element in the non popped array so we start from last buf
        i=0#i=-1
        lli=self.l[i][0].shape[0]
        while (x>lli):
            x-=lli
            i+=1#i-=1
            lli=self.l[i][0].shape[0]
        r=self.l[i][x]
        return r
    def __getslice(self,x,y):
        # 0  is the fist element in the non popped array so we start from last buf
        if (y==x):
            return []
        i=0#i=-1
        lli=self.l[i][0].shape[0]
        while (x>=lli):
            x-=lli
            y-=lli
            #i-=1
            i+=1
            lli=self.l[i][0].shape[0]
        j=i
        llj=lli
        while (y>llj):
            y-=llj
            #j-=1
            j+=1
            if (j==len(self.l)):
                j=j-1
                y=self.l[j][0].shape[0]
            llj=self.l[j][0].shape[0]
        if (i==j):
            r=self.l[i][0][x:y]
            return r
        else:
            #range (i-1,j,-1)
            r=numpy.vstack( [ self.l[i][0][x:,:] ]  + [ self.l[k][0] for k in range (i+1,j) ]  +   [ self.l[j][0][:y,:] ])
            return r
    def get_time_bounds(self,wait=True):
        if (self.mutex.acquire(wait)):
            ttimefrom=self.l[0][2] ## mintime
            ttimeto=self.l[-1][2]+(self.l[-1][0].shape[0]*self.speedrate[1]) ## maxtime
            self.mutex.release()
        return ttimefrom,ttimeto
    def get_time_slice(self,timefrom,timeto,wait=True):
        ## we assume this timeslice is in our queue
        """ get the slice of audio buffers contained in-between the two specified instants,
             these instants must be specified in seconds since the audio started
             (this function suffers from a little bit from approximations (apparently))
         """
        assert(timefrom<=timeto)
        if (self.mutex.acquire(wait)):
            ttimefrom=self.l[0][2] ## mintime
            ttimeto=self.l[-1][2]+(self.l[-1][0].shape[0]*self.speedrate[1]) ## maxtime
            if (ttimeto<ttimefrom):
                print("warning ttimeto < ttimefrom : insonsistent audio queue think to reset audio queues when seeking")
            if (timefrom<ttimefrom):
                print("warning time from slice is before audioqueue memory capacity : fixing !")
                timefrom=ttimefrom
            if (timeto<ttimefrom):
                print("warning timeto slice is before audioqueue memory capacity : fixing !")
                timeto=ttimefrom
            if (timeto>ttimeto):
                print("warning timeto slice is after audioqueue memory capacity : fixing !")
                timeto=ttimeto
            if (timefrom>ttimeto):
                print("warning timefrom slice is after audioqueue memory capacity : fixing !")
                timefrom=ttimeto

            deltafrom=int((timefrom-ttimefrom)*self.samplerate)
            deltato=int((timeto-ttimefrom)*self.samplerate)
            try:
                sl=self.__getslice(deltafrom,deltato)
            except:
                self.mutex.release()
                raise Exception,("error retrieving slice %d:%d"%(deltafrom,deltato))
#             print (self._off+deltafrom,self._off+deltato)
            self.mutex.release()
            return sl
    def get_sampletime_bounds(self,wait=True):
        if (self.mutex.acquire(wait)):
            ttimefrom=self._off ## mintime
            ttimeto=self._off+self._totallen ## maxtime
            self.mutex.release()
        return ttimefrom,ttimeto

    def get_sampletime_slice(self,timefrom,timeto,wait=True):
        ## we assume this timeslice is in our queue
        """ get the slice of audio buffers contained in-between the two specified instants,
             these instants must be specified in seconds since the audio started """
        assert(timefrom<=timeto)
        if (self.mutex.acquire(wait)):
            ttimefrom=self._off ## mintime
            ttimeto=self._off+self._totallen ## maxtime
            if (ttimeto<ttimefrom):
                print("warning ttimeto < ttimefrom : insonsistent audio queue think to reset audio queues when seeking")
            if (timefrom<ttimefrom):
                print("warning time from slice is before audioqueue memory capacity : fixing !")
                timefrom=ttimefrom
            if (timeto<ttimefrom):
                print("warning timeto slice is before audioqueue memory capacity : fixing !")
                timeto=ttimefrom
            if (timeto>ttimeto):
                print("warning timeto slice is after audioqueue memory capacity : fixing !")
                timeto=ttimeto
            if (timefrom>ttimeto):
                print("warning timefrom slice is after audioqueue memory capacity : fixing !")
                timefrom=ttimeto
            deltafrom=(timefrom-ttimefrom)
            deltato=(timeto-ttimefrom)
            try:
                sl=self.__getslice(deltafrom,deltato)
            except:
                self.mutex.release()
                raise Exception,("error retrieving slice %d:%d"%(deltafrom,deltato))
 #            print (self._off+deltafrom,self._off+deltato)
            self.mutex.release()
            return sl
    def print_buffer_stats(self,prefix=""):
        sys.stderr.write(  prefix+" limitsz"+ str(self.limitsz)+"\n")
        sys.stderr.write(  prefix+" offset (mintime)"+str( self._off)+"\n")
        sys.stderr.write(  prefix+" offset (maxtime)"+str( self._off+ self._totallen)+"\n")
        sys.stderr.write(  prefix+" length"+str( self._totallen)+"\n")
        sys.stderr.write(  prefix+" time bounds : "+str( self.get_time_bounds())+"\n")
        sys.stderr.write(  prefix+" sampletime bounds : "+str( self.get_sampletime_bounds())+"\n")
