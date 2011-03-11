# -*- coding: utf-8 -*-

"""
# #######################################################################################
# Pyffmpeg
#
# Copyright (C) 2011 Bertrand Nouvel <bertrand@lm3labs.com>
# Copyright (C) 2008-2010 Bertrand Nouvel <nouvel@nii.ac.jp>
#   Japanese French Laboratory for Informatics -  CNRS
#
# #######################################################################################
#  This file is distibuted under LGPL-3.0
#  See COPYING file attached.
# #######################################################################################
#    Todo :
#       * why seek_before mandatory
#       * Add support for video encoding
#       * add multithread support
#       * Fix first frame bug... 
#
#    Abilities
#     * Frame seeking (TO BE CHECKED again and again)
#
#    Changed compared with pyffmpeg 1:
#     * Clean up destructors
#     * Added compatibility with NumPy and PIL
#     * Added copyless mode for ordered streams/tracks ( when buffers are disabled)
#     * Added audio support
#     * MultiTrack support (possibility to pass paramer)
#     * Added support for streamed video
#     * Updated ID for compatibility with transparency
#     * Updated to latest avcodec primitives

#
"""

#########################################################################################

###################################################################################################
# Based on Pyffmpeg 0.2 by
# Copyright (C) 2006-2007 James Evans <jaevans@users.sf.net>
# Authorization to change from GPL2.0 to LGPL 3.0 provided by original author for this new version
###################################################################################################
#  Declaration and imports
###################################################################################################

import sys
import traceback


###############################################
## Settings
AVCODEC_MAX_AUDIO_FRAME_SIZE=192000
##############################################


#import numpy
#import Image

ctypedef signed char int8_t
ctypedef unsigned char uint8_t
ctypedef signed short int16_t
ctypedef unsigned short uint16_t
ctypedef signed long int32_t
ctypedef signed long long int64_t

cdef enum:
    SEEK_SET = 0
    SEEK_CUR = 1
    SEEK_END = 2

cdef extern from "string.h":
    memcpy(void * dst, void * src, unsigned long sz)
    memset(void * dst, unsigned char c, unsigned long sz)

cdef extern from "Python.h":
    ctypedef int size_t
    object PyBuffer_FromMemory( void *ptr, int size)
    object PyBuffer_FromReadWriteMemory( void *ptr, int size)
    object PyString_FromStringAndSize(char *s, int len)
    void* PyMem_Malloc( size_t n)
    void PyMem_Free( void *p)




#cimport numpy as np
#cdef extern from "numpy/arrayobject.h":
#    void *PyArray_DATA(np.ndarray arr)
AVPROBE_PADDING_SIZE=32

cdef extern from "libavutil/mathematics.h":
    int64_t av_rescale(int64_t a, int64_t b, int64_t c)

cdef extern from "libavformat/avio.h":
    struct ByteIOContext:
        pass
    ctypedef long long int  offset_t

    int get_buffer(ByteIOContext *s, unsigned char *buf, int size)
    int url_ferror(ByteIOContext *s)
    int url_feof(ByteIOContext *s)
    int url_fopen(ByteIOContext **s,  char *filename, int flags)
    int url_setbufsize(ByteIOContext *s, int buf_size)
    int url_fclose(ByteIOContext *s)
    long long int url_fseek(ByteIOContext *s, long long int offset, int whence)
    ByteIOContext *av_alloc_put_byte(
                  unsigned char *buffer,
                  int buffer_size,
                  int write_flag,
                  void *opaque,
                  void * a , void * b , void * c)
                  #int (*read_packet)(void *opaque, uint8_t *buf, int buf_size),
                  #int (*write_packet)(void *opaque, uint8_t *buf, int buf_size),
                  #offset_t (*seek)(void *opaque, offset_t offset, int whence))


cdef extern from "libavutil/mem.h":
    void *av_realloc(void * ptr, unsigned int size)
    void *av_mallocz(unsigned int size)
    void av_freep(void *ptr)

cdef extern from "libavutil/avutil.h":
    cdef enum PixelFormat:
        PIX_FMT_NONE= -1,
        PIX_FMT_YUV420P,   #< Planar YUV 4:2:0 (1 Cr & Cb sample per 2x2 Y samples)
        PIX_FMT_YUV422,    #< Packed pixel, Y0 Cb Y1 Cr
        PIX_FMT_RGB24,     #< Packed pixel, 3 bytes per pixel, RGBRGB...
        PIX_FMT_BGR24,     #< Packed pixel, 3 bytes per pixel, BGRBGR...
        PIX_FMT_YUV422P,   #< Planar YUV 4:2:2 (1 Cr & Cb sample per 2x1 Y samples)
        PIX_FMT_YUV444P,   #< Planar YUV 4:4:4 (1 Cr & Cb sample per 1x1 Y samples)
        PIX_FMT_RGBA32,    #< Packed pixel, 4 bytes per pixel, BGRABstored in cpu endianness
        PIX_FMT_YUV410P,   #< Planar YUV 4:1:0 (1 Cr & Cb sample per 4x4 Y samples)
        PIX_FMT_YUV411P,   #< Planar YUV 4:1:1 (1 Cr & Cb sample per 4x1 Y samples)
        PIX_FMT_RGB565,    #< always stored in cpu endianness
        PIX_FMT_RGB555,    #< always stored in cpu endianness, most significant bit to 1
        PIX_FMT_GRAY8,
        PIX_FMT_MONOWHITE, #< 0 is white
        PIX_FMT_MONOBLACK, #< 0 is black
        PIX_FMT_PAL8,      #< 8 bit with RGBA palette
        PIX_FMT_YUVJ420P,  #< Planar YUV 4:2:0 full scale (jpeg)
        PIX_FMT_YUVJ422P,  #< Planar YUV 4:2:2 full scale (jpeg)
        PIX_FMT_YUVJ444P,  #< Planar YUV 4:4:4 full scale (jpeg)
        PIX_FMT_XVMC_MPEG2_MC,#< XVideo Motion Acceleration via common packet passing(xvmc_render.h)
        PIX_FMT_XVMC_MPEG2_IDCT,
        PIX_FMT_UYVY422,   #< Packed pixel, Cb Y0 Cr Y1
        PIX_FMT_UYVY411,   #< Packed pixel, Cb Y0 Y1 Cr Y2 Y3
        PIX_FMT_NB,

cdef extern from "libavcodec/avcodec.h":
    # use an unamed enum for defines
    cdef enum:
        AVSEEK_FLAG_BACKWARD = 1 #< seek backward
        AVSEEK_FLAG_BYTE     = 2 #< seeking based on position in bytes
        AVSEEK_FLAG_ANY      = 4 #< seek to any frame, even non keyframes
        CODEC_CAP_TRUNCATED = 0x0008
        CODEC_FLAG_TRUNCATED = 0x00010000 # input bitTrack might be truncated at a random location instead of only at frame boundaries
        AV_TIME_BASE = 1000000
        FF_I_TYPE = 1 # Intra
        FF_P_TYPE = 2 # Predicted
        FF_B_TYPE = 3 # Bi-dir predicted
        FF_S_TYPE = 4 # S(GMC)-VOP MPEG4
        FF_SI_TYPE = 5
        FF_SP_TYPE = 6

        AV_NOPTS_VALUE = <int64_t>0x8000000000000000

    enum AVDiscard:
        # we leave some space between them for extensions (drop some keyframes for intra only or drop just some bidir frames)
        AVDISCARD_NONE   = -16 # discard nothing
        AVDISCARD_DEFAULT=   0 # discard useless packets like 0 size packets in avi
        AVDISCARD_NONREF =   8 # discard all non reference
        AVDISCARD_BIDIR  =  16 # discard all bidirectional frames
        AVDISCARD_NONKEY =  32 # discard all frames except keyframes
        AVDISCARD_ALL    =  48 # discard all


#    struct AVCodecContext:
#        int codec_type
#        int codec_id
#        int flags
#        int width
#        int height
#        int pix_fmt
#        int frame_number
#        int hurry_up
#        int skip_idct
#        int skip_frame


    struct AVRational:
        int num
        int den

    struct AVCodecContext:
        int     bit_rate
        int     bit_rate_tolerance
        int     flags
        int     sub_id
        int     me_method
        AVRational     time_base
        int     width
        int     height
        int     gop_size
        int     pix_fmt
        int     rate_emu
        int     sample_rate
        int     channels
        int     sample_fmt
        int     frame_size
        int     frame_number
        int     real_pict_num
        int     delay
        float     qcompress
        float     qblur
        int     qmin
        int     qmax
        int     max_qdiff
        int     max_b_frames
        float     b_quant_factor
        int     rc_strategy
        int     b_frame_strategy
        int     hurry_up
        int     rtp_mode
        int     rtp_payload_size
        int     mv_bits
        int     header_bits
        int     i_tex_bits
        int     p_tex_bits
        int     i_count
        int     p_count
        int     skip_count
        int     misc_bits
        int     frame_bits
        #char     codec_name [32]
        int     codec_type
        int     codec_id
        unsigned int     codec_tag
        int     workaround_bugs
        int     luma_elim_threshold
        int     chroma_elim_threshold
        int     strict_std_compliance
        float     b_quant_offset
        int     error_resilience
        int     has_b_frames
        int     block_align
        int     parse_only
        int     mpeg_quant
        char *     stats_out
        char *     stats_in
        float     rc_qsquish
        float     rc_qmod_amp
        int     rc_qmod_freq
        int     rc_override_count
        char *     rc_eq
        int     rc_max_rate
        int     rc_min_rate
        int     rc_buffer_size
        float     rc_buffer_aggressivity
        float     i_quant_factor
        float     i_quant_offset
        float     rc_initial_cplx
        int     dct_algo
        float     lumi_masking
        float     temporal_cplx_masking
        float     spatial_cplx_masking
        float     p_masking
        float     dark_masking
        int     unused
        int     idct_algo
        int     slice_count
        int *     slice_offset
        int     error_concealment
        unsigned     dsp_mask
        int     bits_per_sample
        int     prediction_method
        AVRational     sample_aspect_ratio
 #       AVFrame *     coded_frame
        int     debug
        int     debug_mv
        #uint64_t     error [4]
        int     mb_qmin
        int     mb_qmax
        int     me_cmp
        int     me_sub_cmp
        int     mb_cmp
        int     ildct_cmp
        int     dia_size
        int     last_predictor_count
        int     pre_me
        int     me_pre_cmp
        int     pre_dia_size
        int     me_subpel_quality
        int     dtg_active_format
        int     me_range
        int     intra_quant_bias
        int     inter_quant_bias
        int     color_table_id
        int     internal_buffer_count
        void *     internal_buffer
        int     global_quality
        int     coder_type
        int     context_model
        int     slice_flags
        int     xvmc_acceleration
        int     mb_decision
        uint16_t *     intra_matrix
        uint16_t *     inter_matrix
        unsigned int     Track_codec_tag
        int     scenechange_threshold
        int     lmin
        int     lmax
        #AVPaletteControl *     palctrl
        int     noise_reduction
        int     rc_initial_buffer_occupancy
        int     inter_threshold
        int     flags2
        int     error_rate
        int     antialias_algo
        int     quantizer_noise_shaping
        int     thread_count
        int     me_threshold
        int     mb_threshold
        int     intra_dc_precision
        int     nsse_weight
        int     skip_top
        int     skip_bottom
        int     profile
        int     level
        int     lowres
        int     coded_width
        int     coded_height
        int     frame_skip_threshold
        int     frame_skip_factor
        int     frame_skip_exp
        int     frame_skip_cmp
        float     border_masking
        int     mb_lmin
        int     mb_lmax
        int     me_penalty_compensation
        int     bidir_refine
        int     brd_scale
        float     crf
        int     cqp
        int     keyint_min
        int     refs
        int     chromaoffset
        int     bframebias
        int     trellis
        float     complexityblur
        int     deblockalpha
        int     deblockbeta
        int     partitions
        int     directpred
        int     cutoff
        int     scenechange_factor
        int     mv0_threshold
        int     b_sensitivity
        int     compression_level
        int     use_lpc
        int     lpc_coeff_precision
        int     min_prediction_order
        int     max_prediction_order
        int     prediction_order_method
        int     min_partition_order
        int     max_partition_order
        int64_t     timecode_frame_start
        int skip_frame
        int skip_idct
        int skip_loop_filter


    enum CodecType:
        CODEC_TYPE_UNKNOWN = -1
        CODEC_TYPE_VIDEO = 0
        CODEC_TYPE_AUDIO = 1
        CODEC_TYPE_DATA = 2
        CODEC_TYPE_SUBTITLE = 3

    struct AVCodec:
        char *name
        int type
        int id
        int priv_data_size
        int capabilities
        AVCodec *next
        AVRational *supported_framerates #array of supported framerates, or NULL if any, array is terminated by {0,0}
        int *pix_fmts       #array of supported pixel formats, or NULL if unknown, array is terminanted by -1

    struct AVPacket:
        int64_t pts                            #< presentation time stamp in time_base units
        int64_t dts                            #< decompression time stamp in time_base units
        char *data
        int   size
        int   stream_index
        int   flags
        int   duration                      #< presentation duration in time_base units (0 if not available)
        void  *priv
        int64_t pos                            #< byte position in Track, -1 if unknown

    struct AVFrame:
        char *data[4]
        int linesize[4]
        int64_t pts
        int pict_type
        int key_frame
        int16_t (*motion_val[2])[2]
        uint8_t motion_subsample_log2

    struct AVPicture:
        uint8_t *data[4]
        int linesize[4]

    AVCodec *avcodec_find_decoder(int id)
    int avcodec_open(AVCodecContext *avctx, AVCodec *codec)
    int avcodec_close(AVCodecContext *avctx)
    int avcodec_decode_video2(AVCodecContext *avctx, AVFrame *picture,
                         int *got_picture_ptr,
                         AVPacket * avpkt)

#    int avcodec_decode_audio2(AVCodecContext *avctx, #AVFrame *picture,
#                         int16_t * samples, int * frames,
#                         void *buf, int buf_size)
    int avcodec_decode_audio3(AVCodecContext *avctx, 
                         int16_t * samples, int * frames,
                         AVPacket * avpkt)

    int avpicture_fill(AVPicture *picture, void *ptr,
                   int pix_fmt, int width, int height)
    AVFrame *avcodec_alloc_frame()
    int avpicture_get_size(int pix_fmt, int width, int height)
    int avpicture_layout(AVPicture* src, int pix_fmt, int width, int height,
                     unsigned char *dest, int dest_size)

    void avcodec_flush_buffers(AVCodecContext *avctx)


OUTPUTMODE_NUMPY=0
OUTPUTMODE_PIL=1



# ##############################################################
# Used for debugging
# ##############################################################


#class DLock:
#    def __init__(self):
#        self.l=threading.Lock()
#    def acquire(self,*args,**kwargs):
#        sys.stderr.write("MTX:"+str((self, "A", args, kwargs))+"\n")
#        try:
#            raise Exception
#        except:
#            if (hasattr(sys,"last_traceback")):
#                traceback.print_tb(sys.last_traceback)
#            else:
#                traceback.print_tb(sys.exc_traceback)
#        sys.stderr.flush()
#        sys.stdout.flush()
#        #return self.l.acquire(*args,**kwargs)
#        return True
#    def release(self):
#        sys.stderr.write("MTX:"+str((self, "R"))+"\n")
#        try:
#            raise Exception
#        except:
#            if (hasattr(sys,"last_traceback")):
#                traceback.print_tb(sys.last_traceback)
#            else:
#                traceback.print_tb(sys.exc_traceback)
#        sys.stderr.flush()
#        sys.stdout.flush()
#        #return self.l.release()

cdef extern from "libavformat/avformat.h":
    struct AVFrac:
        int64_t val, num, den

    void av_register_all()

    struct AVProbeData:
        char *filename
        unsigned char *buf
        int buf_size

    struct AVCodecParserContext:
        pass

    struct AVIndexEntry:
        pass

    struct AVInputFormat:
        char *name
        char *long_name
        char *mime_type
        char *extensions
        int priv_data_size
        int video_codec
        int audio_codec
        int flags
        pass

    struct AVOutputFormat:
        char *name
        char *long_name
        char *mime_type
        char *extensions
        int priv_data_size
        int video_codec
        int audio_codec

    struct AVStream:
        int index    #/* Track index in AVFormatContext */
        int id       #/* format specific Track id */
        AVCodecContext *codec #/* codec context */
        # real base frame rate of the Track.
        # for example if the timebase is 1/90000 and all frames have either
        # approximately 3600 or 1800 timer ticks then r_frame_rate will be 50/1
        AVRational r_frame_rate
        void *priv_data
        # internal data used in av_find_stream_info()
        int64_t codec_info_duration
        int codec_info_nb_frames
        # encoding: PTS generation when outputing Track
        AVFrac pts
        # this is the fundamental unit of time (in seconds) in terms
        # of which frame timestamps are represented. for fixed-fps content,
        # timebase should be 1/framerate and timestamp increments should be
        # identically 1.
        AVRational time_base
        int pts_wrap_bits # number of bits in pts (used for wrapping control)
        # ffmpeg.c private use
        int Track_copy   # if TRUE, just copy Track
        int discard       # < selects which packets can be discarded at will and dont need to be demuxed
        # FIXME move stuff to a flags field?
        # quality, as it has been removed from AVCodecContext and put in AVVideoFrame
        # MN:dunno if thats the right place, for it
        float quality
        # decoding: position of the first frame of the component, in
        # AV_TIME_BASE fractional seconds.
        int64_t start_time
        # decoding: duration of the Track, in AV_TIME_BASE fractional
        # seconds.
        int64_t duration
        char language[4] # ISO 639 3-letter language code (empty string if undefined)
        # av_read_frame() support
        int need_parsing                  # < 1.full parsing needed, 2.only parse headers dont repack
        AVCodecParserContext *parser
        int64_t cur_dts
        int last_IP_duration
        int64_t last_IP_pts
        # av_seek_frame() support
        AVIndexEntry *index_entries # only used if the format does not support seeking natively
        int nb_index_entries
        int index_entries_allocated_size
        int64_t nb_frames                 # < number of frames in this Track if known or 0
        uint8_t *cur_ptr
        int cur_len
        AVPacket cur_pkt

    struct AVFormatContext:
        int nb_streams
        AVInputFormat *iformat
        AVOutputFormat *oformat
        void * priv_data
        AVStream **streams
        int64_t timestamp
        int64_t start_time
        AVStream *cur_st
        #uint8_t *cur_ptr
        #int cur_len
        #AVPacket cur_pkt
        ByteIOContext * pb
        # decoding: total file size. 0 if unknown
        int64_t file_size
        int64_t duration
        # decoding: total Track bitrate in bit/s, 0 if not
        # available. Never set it directly if the file_size and the
        # duration are known as ffmpeg can compute it automatically. */
        int bit_rate
        # av_seek_frame() support
        int64_t data_offset    # offset of the first packet
        int index_built


    struct AVInputFormat:
        pass

    struct AVFormatParameters:
        pass

    int av_open_input_file(AVFormatContext **ic_ptr, char *filename,
                       AVInputFormat *fmt,
                       int buf_size,
                       AVFormatParameters *ap)
    int av_open_input_stream(AVFormatContext **ic_ptr,
                         ByteIOContext *pb,  char *filename,
                         AVInputFormat *fmt, AVFormatParameters *ap)
    void av_close_input_file(AVFormatContext *ic_ptr)
    void av_close_input_stream(AVFormatContext *s)
    int av_find_stream_info(AVFormatContext *ic)

    AVStream *av_new_stream(AVFormatContext *s, int id)

    void dump_format(AVFormatContext *ic,
                 int index,
                 char *url,
                 int is_output)
    void av_free_packet(AVPacket *pkt)
    int av_read_packet(AVFormatContext *s, AVPacket *pkt)
    int av_read_frame(AVFormatContext *s, AVPacket *pkt)
    int av_seek_frame(AVFormatContext *s, int Track_index, int64_t timestamp, int flags)
    int av_seek_frame_binary(AVFormatContext *s, int Track_index, int64_t target_ts, int flags)

    void av_parser_close(AVCodecParserContext *s)

    int av_index_search_timestamp(AVStream *st, int64_t timestamp, int flags)
    AVInputFormat *av_probe_input_format(AVProbeData *pd, int is_opened)
    AVInputFormat *av_probe_input_format2(AVProbeData *pd, int is_opened,int * score)
    AVFormatContext *  avformat_alloc_context()
    AVOutputFormat *guess_format(char *short_name, char *filename,char *mime_type)

cdef __registered
__registered = 0


cdef extern void av_free(void *ptr)

cdef extern from "libswscale/swscale.h":
    cdef enum:
        SWS_FAST_BILINEAR,
        SWS_BILINEAR,
        SWS_BICUBIC,
        SWS_X,
        SWS_POINT,
        SWS_AREA,
        SWS_BICUBLIN,
        SWS_GAUSS,
        SWS_SINC,
        SWS_LANCZOS,
        SWS_SPLINE

    struct SwsContext:
        pass

    struct SwsFilter:
        pass

    SwsContext *sws_getContext(int srcW, int srcH, int srcFormat, int dstW, int dstH, int dstFormat, int flags,SwsFilter *srcFilter, SwsFilter *dstFilter, double *param)
    void sws_freeContext(SwsContext *swsContext)
    int sws_scale(SwsContext *context, uint8_t* src[], int srcStride[], int srcSliceY,int srcSliceH, uint8_t* dst[], int dstStride[])



cdef extern from "Python.h":
    ctypedef unsigned long size_t
    object PyBuffer_FromMemory( void *ptr, int size)
    object PyBuffer_FromReadWriteMemory( void *ptr, int size)
    object PyString_FromStringAndSize(char *s, int len)
    void* PyMem_Malloc( size_t n)
    void PyMem_Free( void *p)


def rwbuffer_at(pos,len):
    cdef unsigned long ptr=int(pos)
    return PyBuffer_FromReadWriteMemory(<void *>ptr,len)

#cdef extern from "avio.h":
#    int url_ferror(ByteIOContext* s)
#    int url_feof(ByteIOContext* s)


##################################################################
# General includes
##################################################################


try:
    import numpy
    from pyffmpeg_numpybindings import *
except:
    numpy=None

try:
    import PIL
    from PIL import Image
except:
    Image=None








##################################################################
# Utility elements
##################################################################



def py_av_register_all():
    if __registered:
        return
    __registered = 1
    av_register_all()

cdef AVRational AV_TIME_BASE_Q
AV_TIME_BASE_Q.num = 1
AV_TIME_BASE_Q.den = AV_TIME_BASE
AVFMT_NOFILE=1

cdef av_read_frame_flush        (       AVFormatContext *        s )  :
    cdef AVStream *st
    cdef int i
    #flush_packet_queue(s);
    if (s.cur_st) :
        #if (s.cur_st.parser):
        #    av_free_packet(&s.cur_st.cur_pkt)
        s.cur_st = NULL

    #s.cur_st.cur_ptr = NULL;
    #s.cur_st.cur_len = 0;

    for i in range(s.nb_streams) :
        st = s.streams[i]

    if (st.parser) :
        av_parser_close(st.parser)
        st.parser = NULL
        st.last_IP_pts = AV_NOPTS_VALUE
        st.cur_dts = 0


#########################################################################################################
## AudioQueue Object  (This may later be exported with another object)
#########################################################################################################

cdef DEBUG(s):
    sys.stderr.write("DEBUG: %s\n"%(s,))
    sys.stderr.flush()

## contains pairs of timestamp, array

try:
    from audioqueue import AudioQueue, Queue_Empty, Queue_Full
except:
    pass


##################################################################
# Initialization
##################################################################
py_av_register_all()



###############################################################################
## Some common settings
###############################################################################
TS_AUDIOVIDEO={'video1':(CODEC_TYPE_VIDEO, -1,  {}), 'audio1':(CODEC_TYPE_AUDIO, -1, {})}
TS_AUDIO={ 'audio1':(CODEC_TYPE_AUDIO, -1, {})}
TS_VIDEO={ 'video1':(CODEC_TYPE_VIDEO, -1, {})}
TS_VIDEO_PIL={ 'video1':(CODEC_TYPE_VIDEO, -1, {'outputmode':OUTPUTMODE_PIL})}





###############################################################################
## The Abstract Reader Class
###############################################################################

cdef class AFFMpegReader:
    """ Abstract version of FFMpegReader"""
    ### File
    cdef object filename
    ### used when streaming
    cdef ByteIOContext *io_context
    ### Tracks contained in the file
    cdef object tracks
    cdef void * ctracks
    ### current timing
    cdef float opts ## orginal pts recoded as a float
    cdef unsigned long long int pts
    cdef unsigned long long int dts
    cdef unsigned long long int errjmppts # when trying to skip over buggy area
    cdef unsigned long int frameno
    cdef float fps # real frame per seconds (not declared one)
    cdef float tps # ticks per seconds

    cdef AVPacket * packet
    cdef AVPacket * prepacket
    cdef AVPacket packetbufa
    cdef AVPacket packetbufb
    cdef int altpacket
    #
    cdef bint observers_enabled


    cdef AVFormatContext *FormatCtx
 #   self.prepacket=<AVPacket *>None
#   self.packet=&self.packetbufa

    def __new__(self):
        pass

    def dump(self):
        pass

    def open(self,char *filename, track_selector={'video1':(CODEC_TYPE_VIDEO, -1), 'audio1':(CODEC_TYPE_AUDIO, -1)}):
        pass

    def close(self):
        pass

    cdef read_packet(self):
        print "FATAL Error This function is abstract and should never be called, it is likely that you compiled pyffmpeg with a too old version of pyffmpeg !!!"
        print "Try running 'easy_install -U cython' and rerun the pyffmpeg2 install"
        assert(False)

    def process_current_packet(self):
        pass

    def __prefetch_packet(self):
        pass

    def read_until_next_frame(self):
        pass

cdef class Track:
    """
     A track is used for memorizing all the aspect related to
     Video, or an Audio Track.

     Practically a Track is managing the decoder context for itself.
    """
    cdef AFFMpegReader vr
    cdef int no
    ## cdef AVFormatContext *FormatCtx
    cdef AVCodecContext *CodecCtx
    cdef AVCodec *Codec
    cdef AVFrame *frame
    cdef AVStream *stream
    cdef long start_time
    cdef object packet_queue
    cdef frame_queue
    cdef unsigned long long int pts
    cdef unsigned long long int last_pts
    cdef unsigned long long int last_dts
    cdef object observer
    cdef int support_truncated
    cdef int do_check_start
    cdef int do_check_end
    cdef int reopen_codec_on_buffer_reset

    cdef __new__(Track self):
        self.vr=None
        self.observer=None
        self.support_truncated=1
        self.reopen_codec_on_buffer_reset=1

    def get_no(self):
        """Returns the number of the tracks."""
        return self.no

    def __len__(self):
        """Returns the number of data frames on this track."""
        return self.stream.nb_frames

    def duration(self):
        """Return the duration of one track in PTS"""
        if (self.stream.duration==0x8000000000000000):
            raise KeyError
        return self.stream.duration

    def _set_duration(self,x):
        """Allows to set the duration to correct inconsistent information"""
        self.stream.duration=x

    def duration_time(self):
        """ returns the duration of one track in seconds."""
        return float(self.duration())/ (<float>AV_TIME_BASE)

    cdef init0(Track self,  AFFMpegReader vr,int no, AVCodecContext *CodecCtx):
        """ This is a private constructor """
        self.vr=vr
        self.CodecCtx=CodecCtx
        self.no=no
        self.stream = self.vr.FormatCtx.streams[self.no]
        self.frame_queue=[]
        self.Codec = avcodec_find_decoder(self.CodecCtx.codec_id)
        self.frame = avcodec_alloc_frame()
        self.start_time=self.stream.start_time
        self.do_check_start=0
        self.do_check_end=0


    def init(self,observer=None, support_truncated=0,   **args):
        """ This is a private constructor

            It supports also the following parameted from ffmpeg
            skip_frame
            skip_idct
            skip_loop_filter
            hurry_up
            dct_algo
            idct_algo

            To set all value for keyframes_only
            just set up hurry_mode to any value.
        """
        self.observer=None
        self.support_truncated=support_truncated
        for k in args.keys():
            if k not in [ "skip_frame", "skip_loop_filter", "skip_idct", "hurry_up", "hurry_mode", "dct_algo", "idct_algo", "check_start" ,"check_end"]:
                sys.stderr.write("warning unsupported arguments in stream initialization :"+k+"\n")
        if self.Codec == NULL:
            raise IOError("Unable to get decoder")
        if (self.Codec.capabilities & CODEC_CAP_TRUNCATED) and (self.support_truncated!=0):
            self.CodecCtx.flags = self.CodecCtx.flags | CODEC_FLAG_TRUNCATED
        avcodec_open(self.CodecCtx, self.Codec)
        if args.has_key("hurry_mode"):
            self.CodecCtx.hurry_up=2
            self.CodecCtx.skip_loop_filter=32
            self.CodecCtx.skip_frame=32
            self.CodecCtx.skip_idct=32
        if args.has_key("skip_frame"):
            self.CodecCtx.skip_frame=args["skip_frame"]
        if args.has_key("skip_idct"):
            self.CodecCtx.skip_idct=args["skip_idct"]
        if args.has_key("skip_loop_filter"):
            self.CodecCtx.skip_loop_filter=args["skip_loop_filter"]
        if args.has_key("hurry_up"):
            self.CodecCtx.skip_loop_filter=args["hurry_up"]
        if args.has_key("dct_algo"):
            self.CodecCtx.dct_algo=args["dct_algo"]
        if args.has_key("idct_algo"):
            self.CodecCtx.idct_algo=args["idct_algo"]
        if (not args.has_key("check_start") or args["check_start"]):
            self.do_check_start=1
        if (args.has_key("check_end") and args["check_end"]):
            self.do_check_end=0


    def check_start(self):
        """ It seems that many file have incorrect initial time information.
            The best way to avoid offset in shifting is thus to check what
            is the time of the beginning of the track.
        """
        if (self.do_check_start):
            try:
                self.seek_to_pts(0)
                self.vr.read_until_next_frame()
                sys.stderr.write("start time checked : pts = %d , declared was : %d\n"%(self.pts,self.start_time))
                self.start_time=self.pts
                self.seek_to_pts(0)
                self.do_check_start=0
            except Exception,e:
                #DEBUG("check start FAILED " + str(e))
                pass
        else:
            pass


    def check_end(self):
        """ It seems that many file have incorrect initial time information.
            The best way to avoid offset in shifting is thus to check what
            is the time of the beginning of the track.
        """
        if (self.do_check_end):
            try:
                self.vr.packetbufa.dts=self.vr.packetbufa.pts=self.vr.packetbufb.dts=self.vr.packetbufb.pts=0
                self.seek_to_pts(0x00FFFFFFFFFFFFF)
                self.vr.read_packet()
                try:
                    dx=self.duration()
                except:
                    dx=-1
                newend=max(self.vr.packetbufa.dts,self.vr.packetbufa.pts,self.vr.packetbufb.dts)
                sys.stderr.write("end time checked : pts = %d, declared was : %d\n"%(newend,dx))
                assert((newend-self.start_time)>=0)
                self._set_duration((newend-self.start_time))
                self.vr.reset_buffers()
                self.seek_to_pts(0)
                self.do_check_end=0
            except Exception,e:
                DEBUG("check end FAILED " + str(e))
                pass
        else:
            #DEBUG("no check end " )
            pass

    def set_observer(self, observer=None):
        """ An observer is a callback function that is called when a new
            frame of data arrives.

            Using this function you may setup the function to be called when
            a frame of data is decoded on that track.
        """
        self.observer=observer

    def _reopencodec(self):
        """
          This is used to reset the codec context.
          Very often, this is the safest way to get everything clean
          when seeking.
        """
        if (self.CodecCtx!=NULL):
            avcodec_close(self.CodecCtx)
        self.CodecCtx=NULL
        self.CodecCtx = self.vr.FormatCtx.streams[self.no].codec
        self.Codec = avcodec_find_decoder(self.CodecCtx.codec_id)
        if self.Codec == NULL:
            raise IOError("Unable to get decoder")
        if (self.Codec.capabilities & CODEC_CAP_TRUNCATED) and (self.support_truncated!=0):
            self.CodecCtx.flags = self.CodecCtx.flags | CODEC_FLAG_TRUNCATED
        ret = avcodec_open(self.CodecCtx, self.Codec)

    def close(self):
        """
           This closes the track. And thus closes the context."
        """
        if (self.CodecCtx!=NULL):
            avcodec_close(self.CodecCtx)
        self.CodecCtx=NULL

    def prepare_to_read_ahead(self):
        """
        In order to avoid delay during reading, our player try always
        to read a little bit of that is available ahead.
        """
        pass

    def reset_buffers(self):
        """
        This function is used on seek to reset everything.
        """
        self.pts=0
        self.last_pts=0
        self.last_dts=0
        if (self.CodecCtx!=NULL):
            avcodec_flush_buffers(self.CodecCtx)
        ## violent solution but the most efficient so far...
        if (self.reopen_codec_on_buffer_reset):
            self._reopencodec()

    #  cdef process_packet(self, AVPacket * pkt):
    #      print "FATAL : process_packet : Error This function is abstract and should never be called, it is likely that you compiled pyffmpeg with a too old version of pyffmpeg !!!"
    #      print "Try running 'easy_install -U cython' and rerun the pyffmpeg2 install"
    #      assert(False)

    def seek_to_seconds(self, seconds ):
        """ Seek to the specified time in seconds.

            Note that seeking is always bit more complicated when we want to be exact.
            * We do not use any precomputed index structure for seeking (which would make seeking exact)
            * Due to codec limitations, FFMPEG often provide approximative seeking capabilites
            * Sometimes "time data" in video file are invalid
            * Sometimes "seeking is simply not possible"

            We are working on improving our seeking capabilities.
        """
        pts = (<float>seconds) * (<float>AV_TIME_BASE)
        #pts=av_rescale(seconds*AV_TIME_BASE, self.stream.time_base.den, self.stream.time_base.num*AV_TIME_BASE)
        self.seek_to_pts(pts)

    def seek_to_pts(self,  unsigned long long int pts):
        """ Seek to the specified PTS

            Note that seeking is always bit more complicated when we want to be exact.
            * We do not use any precomputed index structure for seeking (which would make seeking exact)
            * Due to codec limitations, FFMPEG often provide approximative seeking capabilites
            * Sometimes "time data" in video file are invalid
            * Sometimes "seeking is simply not possible"

            We are working on improving our seeking capabilities.
        """

        if (self.start_time!=AV_NOPTS_VALUE):
            pts+=self.start_time


        self.vr.seek_to(pts)



cdef class AudioPacketDecoder:
    cdef uint8_t *audio_pkt_data
    cdef int audio_pkt_size

    cdef __new__(self):
        self.audio_pkt_data =<uint8_t *>NULL
        self.audio_pkt_size=0

    cdef int audio_decode_frame(self,  AVCodecContext *aCodecCtx,
            uint8_t *audio_buf,  int buf_size, double * pts_ptr, 
            double * audio_clock, int nchannels, int samplerate, AVPacket * pkt, int first) :
        cdef double pts
        cdef int n
        cdef int len1
        cdef int data_size

        
        data_size = buf_size
        #print "datasize",data_size
        len1 = avcodec_decode_audio3(aCodecCtx, <int16_t *>audio_buf, &data_size, pkt);
        if(len1 < 0) :
                raise IOError,("Audio decoding error (i)",len1)
        if(data_size < 0) :
                raise IOError,("Audio decoding error (ii)",data_size)

        #We have data, return it and come back for more later */
        pts = audio_clock[0]
        pts_ptr[0] = pts
        n = 2 * nchannels
        audio_clock[0] += ((<double>data_size) / (<double>(n * samplerate)))
        return data_size;


###############################################################################
## The AudioTrack Class
###############################################################################


cdef class AudioTrack(Track):
    cdef object audioq   #< This queue memorize the data to be reagglomerated
    cdef object audiohq  #< This queue contains the audio packet for hardware devices
    cdef double clock    #< Just a clock
    cdef AudioPacketDecoder apd
    cdef float tps
    cdef int data_size
    cdef int rdata_size
    cdef int sdata_size
    cdef int dest_frame_overlap #< If you want to computer spectrograms it may be useful to have overlap in-between data
    cdef int dest_frame_size
    cdef int hardware_queue_len
    cdef object lf
    cdef int os
    cdef object audio_buf # buffer used in decoding of  audio

    def init(self, tps=30, hardware_queue_len=5, dest_frame_size=0, dest_frame_overlap=0, **args):
        """
        The "tps" denotes the assumed frame per seconds.
        This is use to synchronize the emission of audio packets with video packets.

        The hardware_queue_len, denotes the output audio queue len, in this queue all packets have a size determined by dest_frame_size or tps

        dest_frame_size specifies the size of desired audio frames,
        when dest_frame_overlap is not null some datas will be kept in between
        consecutive audioframes, this is useful for computing spectrograms.

        """
        assert (numpy!=None), "NumPy must be available for audio support to work. Please install numpy."
        Track.init(self,  **args)
        self.tps=tps
        self.hardware_queue_len=hardware_queue_len
        self.dest_frame_size=dest_frame_size
        self.dest_frame_overlap=dest_frame_overlap

        #
        # audiohq =
        # hardware queue : agglomerated and time marked packets of a specific size (based on audioq)
        #
        self.audiohq=AudioQueue(limitsz=self.hardware_queue_len)
        self.audioq=AudioQueue(limitsz=12,tps=self.tps,
                              samplerate=self.CodecCtx.sample_rate,
                              destframesize=self.dest_frame_size if (self.dest_frame_size!=0) else (self.CodecCtx.sample_rate//self.tps),
                              destframeoverlap=self.dest_frame_overlap,
                              destframequeue=self.audiohq)



        self.data_size=AVCODEC_MAX_AUDIO_FRAME_SIZE # ok let's try for try
        self.sdata_size=0
        self.rdata_size=self.data_size-self.sdata_size
        self.audio_buf=numpy.ones((AVCODEC_MAX_AUDIO_FRAME_SIZE,self.CodecCtx.channels),dtype=numpy.int16 )
        self.clock=0
        self.apd=AudioPacketDecoder()
        self.os=0
        self.lf=None

    def reset_tps(self,tps):
        self.tps=tps
        self.audiohq=AudioQueue(limitsz=self.hardware_queue_len)  # hardware queue : agglomerated and time marked packets of a specific size (based on audioq)
        self.audioq=AudioQueue(limitsz=12,tps=self.tps,
                              samplerate=self.CodecCtx.sample_rate,
                              destframesize=self.dest_frame_size if (self.dest_frame_size!=0) else (self.CodecCtx.sample_rate//self.tps),
#                              destframesize=self.dest_frame_size or (self.CodecCtx.sample_rate//self.tps),
                              destframeoverlap=self.dest_frame_overlap,
                              destframequeue=self.audiohq)


    def get_cur_pts(self):
        return self.last_pts

    def reset_buffers(self):
        ## violent solution but the most efficient so far...
        Track.reset_buffers(self)
        try:
            while True:
                self.audioq.get()
        except Queue_Empty:
            pass
        try:
            while True:
                self.audiohq.get()
        except Queue_Empty:
            pass
        self.apd=AudioPacketDecoder()

    def get_channels(self):
        """ Returns the number of channels of the AudioTrack."""
        return self.CodecCtx.channels

    def get_samplerate(self):
        """ Returns the samplerate of the AudioTrack."""
        return self.CodecCtx.sample_rate

    def get_audio_queue(self):
        """ Returns the audioqueue where received packets are agglomerated to form
            audio frames of the desired size."""
        return self.audioq

    def get_audio_hardware_queue(self):
        """ Returns the audioqueue where data are stored while waiting to be used by user."""
        return self.audiohq

    def __read_subsequent_audio(self):
        """ This function is used internally to do some read ahead.

        we will push in the audio queue the datas that appear after a specified frame,
        or until the audioqueue is full
        """
        calltrack=self.get_no()
        #DEBUG("read_subsequent_audio")
        if (self.vr.tracks[0].get_no()==self.get_no()):
            calltrack=-1
        self.vr.read_until_next_frame(calltrack=calltrack)
        #self.audioq.print_buffer_stats()

    cdef process_packet(self, AVPacket * pkt):
        cdef double xpts
        self.rdata_size=self.data_size
        lf=2
        audio_size=self.rdata_size*lf
	
        first=1
        #DEBUG( "process packet size=%s pts=%s dts=%s "%(str(pkt.size),str(pkt.pts),str(pkt.dts)))
        if (audio_size>0):
            audio_size=self.rdata_size*lf
            audio_size = self.apd.audio_decode_frame(self.CodecCtx,
                                      <uint8_t *> <unsigned long long> (PyArray_DATA_content( self.audio_buf)),
                                      audio_size,
                                      &xpts,
                                      &self.clock,
                                      self.CodecCtx.channels,
                                      self.CodecCtx.sample_rate,
                                      pkt,
                                      first)
            first=0
            if (audio_size>0):
                self.os+=1
                audio_start=0
                len1 = audio_size
                bb= ( audio_start )//lf
                eb= ( audio_start +(len1//self.CodecCtx.channels) )//lf
                if pkt.pts == AV_NOPTS_VALUE:
                    pts = pkt.dts
                else:
                    pts = pkt.pts
                opts=pts
                #self.pts=pts
                self.last_pts=av_rescale(pkt.pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
                self.last_dts=av_rescale(pkt.dts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
                xpts= av_rescale(pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
                xpts=float(pts)/AV_TIME_BASE
                cb=self.audio_buf[bb:eb].copy()
                self.lf=cb
                self.audioq.putforce((cb,pts,float(opts)/self.tps)) ## this audio q is for processing
                #print ("tp [%d:%d]/as:%d/bs:%d:"%(bb,eb,audio_size,self.Adata_size))+str(cb.mean())+","+str(cb.std())
                self.rdata_size=self.data_size
        if (self.observer):
            try:
                while (True) :
                    x=self.audiohq.get_nowait()
                    if (self.vr.observers_enabled):
                        self.observer(x)
            except Queue_Empty:
                pass

    def prepare_to_read_ahead(self):
        """ This function is used internally to do some read ahead """
        self.__read_subsequent_audio()

    def get_next_frame(self):
        """
        Reads a packet and return last decoded frame.

        NOTE : Usage of this function is discouraged for now.

        TODO : Check again this function
        """
        os=self.os
        #DEBUG("AudioTrack : get_next_frame")
        while (os==self.os):
            self.vr.read_packet()
        #DEBUG("/AudioTrack : get_next_frame")
        return self.lf

    def get_current_frame(self):
        """
          Reads audio packet so that the audioqueue contains enough data for
          one one frame, and then decodes that frame

          NOTE : Usage of this function is discouraged for now.

          TODO : this approximative yet
          TODO : this shall use the hardware queue
        """

        dur=int(self.get_samplerate()//self.tps)
        while (len(self.audioq)<dur):
            self.vr.read_packet()
        return self.audioq[0:dur]

    def print_buffer_stats(self):
        ##
        ##
        ##
        self.audioq.print_buffer_stats("audio queue")






###############################################################################
## The VideoTrack Class
###############################################################################


cdef class VideoTrack(Track):
    """
        VideoTrack implement a video codec to access the videofile.

        VideoTrack reads in advance up to videoframebanksz frames in the file.
        The frames are put in a temporary pool with their presentation time.
        When the next image is queried the system look at for the image the most likely to be the next one...
    """

    cdef int outputmode
    cdef int pixel_format
    cdef int frameno
    cdef int videoframebanksz
    cdef object videoframebank ### we use this to reorder image though time
    cdef object videoframebuffers ### TODO : Make use of these buffers
    cdef int videobuffers
    cdef int hurried_frames
    cdef int width
    cdef int height
    cdef int dest_height
    cdef int dest_width
    cdef int with_motion_vectors
    cdef  SwsContext * convert_ctx




    def init(self, pixel_format=-1, videoframebanksz=1, dest_width=-1, dest_height=-1,videobuffers=2,outputmode=OUTPUTMODE_NUMPY,with_motion_vectors=0,** args):
        """ Construct a video track decoder for a specified image format

            You may specify :

            pixel_format to force data to be in a specified pixel format.
            (note that only array like formats are supported, i.e. no YUV422)

            dest_width, dest_height in order to force a certain size of output

            outputmode : 0 for numpy , 1 for PIL

            videobuffers : Number of video buffers allocated
            videoframebanksz : Number of decoded buffers to be kept in memory

            It supports also the following parameted from ffmpeg
            skip_frame
            skip_idct
            skip_loop_filter
            hurry_up
            dct_algo
            idct_algo

            To set all value for keyframes_only
            just set up hurry_mode to any value.

        """
        cdef int numBytes
        Track.init(self,  **args)
        self.outputmode=outputmode
        self.pixel_format=pixel_format
        if (self.pixel_format==-1):
            self.pixel_format=PIX_FMT_RGB24
        self.videoframebank=[]
        self.videoframebanksz=videoframebanksz
        self.videobuffers=videobuffers
        self.with_motion_vectors=with_motion_vectors
        self.width = self.CodecCtx.width
        self.height = self.CodecCtx.height
        #self.CodecCtx.skip_frame=skip_frame
        #self.CodecCtx.skip_idct=skip_frame
        self.dest_width=(dest_width==-1) and self.width or dest_width
        self.dest_height=(dest_height==-1) and self.height or dest_height
        numBytes=avpicture_get_size(self.pixel_format, self.dest_width, self.dest_height)
        #print  "numBytes", numBytes,self.pixel_format,
        if (outputmode==OUTPUTMODE_NUMPY):
            #print "shape", (self.dest_height, self.dest_width,numBytes/(self.dest_width*self.dest_height))
            self.videoframebuffers=[ numpy.zeros(shape=(self.dest_height, self.dest_width,
                                                        numBytes/(self.dest_width*self.dest_height)),  dtype=numpy.uint8)      for i in range(self.videobuffers) ]
        else:
            assert self.pixel_format==PIX_FMT_RGB24, "While using PIL only RGB pixel format is supported by pyffmpeg"
            self.videoframebuffers=[ Image.new("RGB",(self.dest_width,self.dest_height)) for i in range(self.videobuffers) ]
        self.convert_ctx = sws_getContext(self.width, self.height, self.CodecCtx.pix_fmt, self.dest_width,self.dest_height,self.pixel_format, SWS_BILINEAR, NULL, NULL, NULL)
        if self.convert_ctx == NULL:
            raise MemoryError("Unable to allocate scaler context")


    def reset_buffers(self):
        """ Reset the internal buffers. """

        Track.reset_buffers(self)
        for x in self.videoframebank:
            self.videoframebuffers.append(x[2])
        self.videoframebank=[]


    def print_buffer_stats(self):
        """ Display some informations on internal buffer system """

        print "video buffers :", len(self.videoframebank), " used out of ", self.videoframebanksz


    def get_cur_pts(self):

        return self.last_pts



    def get_orig_size(self) :
        """ return the size of the image in the current video track """

        return (self.width,  self.height)


    def get_size(self) :
        """ return the size of the image in the current video track """

        return (self.dest_width,  self.dest_height)


    def close(self):
        """ closes the track and releases the video decoder """

        Track.close(self)
        if (self.convert_ctx!=NULL):
            sws_freeContext(self.convert_ctx)
        self.convert_ctx=NULL


    cdef _read_current_motion_vectors(self,AVFrame * f):
        cdef int mv_sample_log2
        cdef int mv_width
        cdef int mv_height
        cdef int mv_stride
        cdef int x,y,mv_x,mv_y,direction

        mv_sample_log2= 4 - f.motion_subsample_log2
        mb_width= (self.width+15)>>4
        mb_height= (self.height+15)>>4
        mv_stride= (mb_width << mv_sample_log2) + 1
        dtype=numpy.int16
        res=numpy.zeros((mb_height,mb_width,2),dtype=dtype)
        mv_x=mv_y=0
        for direction in range(2):
            for x in range(mb_width):
                for y in range(mb_height):
                    res[y,x,direction]=f.motion_val[0][x + y*mv_stride][direction]
        return res


    cdef process_packet(self, AVPacket *packet):

        cdef int frameFinished=0
        ret = avcodec_decode_video2(self.CodecCtx,self.frame,&frameFinished,packet)
        #DEBUG( "process packet size=%s pts=%s dts=%s keyframe=%d picttype=%d"%(str(packet.size),str(packet.pts),str(packet.dts),self.frame.key_frame,self.frame.pict_type))
        if ret < 0:
                #DEBUG("IOError")
            raise IOError("Unable to decode video picture: %d" % (ret,))
        if (frameFinished):
            #DEBUG("frame finished")
            self.on_frame_finished()
        self.last_pts=av_rescale(packet.pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        self.last_dts=av_rescale(packet.dts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        #DEBUG("/__nextframe")

    #########################################
    ### FRAME READING RELATED ISSUE
    #########################################


    def get_next_frame(self):
        """ reads the next frame and observe it if necessary"""

        #DEBUG("videotrack get_next_frame")
        self.__next_frame()
        #DEBUG("__next_frame done")
        am=self.smallest_videobank_time()
        #print am
        f=self.videoframebank[am][2]
        if (self.vr.observers_enabled):
            if (self.observer):
                self.observer(f)
        #DEBUG("/videotack get_next_frame")
        return f



    def get_current_frame(self):
        """ return the image with the smallest time index among the not yet displayed decoded frame """

        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am]



    def _internal_get_current_frame(self):
        """
            This function is normally not aimed to be called by user it essentially does a conversion in-between the picture that is being decoded...
        """

        cdef AVFrame *pFrameRes
        cdef int numBytes
        if self.outputmode==OUTPUTMODE_NUMPY:
            img_image=self.videoframebuffers.pop()
            pFrameRes = self._convert_withbuf(<AVPicture *>self.frame,<char *><unsigned long long>PyArray_DATA_content(img_image))
        else:
            img_image=self.videoframebuffers.pop()
            bufferdata="\0"*(self.dest_width*self.dest_height*3)
            pFrameRes = self._convert_withbuf(<AVPicture *>self.frame,<char *>bufferdata)
            img_image.fromstring(bufferdata)
        av_free(pFrameRes)
        return img_image



    def _get_current_frame_without_copy(self,numpyarr):
        """
            This function is normally returns without copying it the image that is been read
            TODO: Make this work at the correct time (not at the position at the preload cursor)
        """

        cdef AVFrame *pFrameRes
        cdef int numBytes
        numBytes=avpicture_get_size(self.pixel_format, self.CodecCtx.width, self.CodecCtx.height)
        if (self.numpy):
            pFrameRes = self._convert_withbuf(<AVPicture *>self.frame,<char *><unsigned long long>PyArray_DATA_content(numpyarr))
        else:
            raise Exception, "Not yet implemented" # TODO : <



    def on_frame_finished(self):
        #DEBUG("on frame finished")
        if self.vr.packet.pts == AV_NOPTS_VALUE:
            pts = self.vr.packet.dts
        else:
            pts = self.vr.packet.pts
        self.pts=av_rescale(pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        #print "unparsed pts", pts,  self.stream.time_base.num,self.stream.time_base.den,  self.pts
        self.frameno+=1
        frametype=self.frame.pict_type
        if (self.with_motion_vectors):
            motion_vectors=self._read_current_motion_vectors(self.frame)
        else:
            motion_vectors=None
        self.videoframebank.append((self.pts,self.frameno,self._internal_get_current_frame(),frametype,motion_vectors))
        if (len(self.videoframebank)>self.videoframebanksz):
            self.videoframebuffers.append(self.videoframebank.pop(0)[2])
        #DEBUG("/on_frame_finished")

    def __next_frame(self):
        cdef int fno
        cfno=self.frameno
        while (cfno==self.frameno):
            #DEBUG("__nextframe : reading packet...")
            self.vr.read_packet()
        return self.pts
        #return av_rescale(pts,AV_TIME_BASE * <int64_t>Track.time_base.num,Track.time_base.den)






    ########################################
    ### videoframebank management
    #########################################

    def prefill_videobank(self):
        """ Use for read ahead : fill in the video buffer """

        if (len(self.videoframebank)<self.videoframebanksz):
            self.__next_frame()



    def refill_videobank(self,no=0):
        """ empty (partially) the videobank and refill it """

        if not no:
            for x in self.videoframebank:
                self.videoframebuffers.extend(x[2])
            self.videoframebank=[]
            self.prefill_videobank()
        else:
            for i in range(self.videoframebanksz-no):
                self.__next_frame()



    def smallest_videobank_time(self):
        """ returns the index of the frame in the videoframe bank that have the smallest time index """

        mi=0
        if (len(self.videoframebank)==0):
            raise Exception,"empty"
        vi=self.videoframebank[mi][0]
        for i in range(1,len(self.videoframebank)):
            if (vi<self.videoframebank[mi][0]):
                mi=i
                vi=self.videoframebank[mi][0]
        return mi



    def prepare_to_read_ahead(self):
        """ generic function called after seeking to prepare the buffer """
        self.prefill_videobank()


    ########################################
    ### misc
    #########################################

    def _finalize_seek(self, rtargetPts):
        while True:
            self.__next_frame()
#           if (self.debug_seek):
#             sys.stderr.write("finalize_seek : %d\n"%(self.pts,))
            if self.pts >= rtargetPts:
                break


    def set_hurry(self, b=1):
        #if we hurry it we can get bad frames later in the GOP
        if (b) :
            self.CodecCtx.skip_idct = AVDISCARD_BIDIR
            self.CodecCtx.skip_frame = AVDISCARD_BIDIR
            self.CodecCtx.hurry_up = 1
            self.hurried_frames = 0
        else:
            self.CodecCtx.skip_idct = 0
            self.CodecCtx.skip_frame = 0
            self.CodecCtx.hurry_up = 0

    ########################################
    ###
    ########################################


    cdef AVFrame *_convert_to(self,AVPicture *frame, int pixformat=-1):
        """ Convert AVFrame to a specified format (Intended for copy) """

        cdef AVFrame *pFrame
        cdef int numBytes
        cdef char *rgb_buffer
        cdef int width,height
        cdef AVCodecContext *pCodecCtx = self.CodecCtx

        if (pixformat==-1):
            pixformat=self.pixel_format

        pFrame = avcodec_alloc_frame()
        if pFrame == NULL:
            raise MemoryError("Unable to allocate frame")
        width = self.dest_width
        height = self.dest_height
        numBytes=avpicture_get_size(pixformat, width,height)
        rgb_buffer = <char *>PyMem_Malloc(numBytes)
        avpicture_fill(<AVPicture *>pFrame, <uint8_t *>rgb_buffer, pixformat,width, height)
        sws_scale(self.convert_ctx, frame.data, frame.linesize, 0, self.height, <uint8_t **>pFrame.data, pFrame.linesize)
        if (pFrame==NULL):
            raise Exception,("software scale conversion error")
        return pFrame






    cdef AVFrame *_convert_withbuf(self,AVPicture *frame,char *buf,  int pixformat=-1):
        """ Convert AVFrame to a specified format (Intended for copy)  """

        cdef AVFrame *pFramePixFormat
        cdef int numBytes
        cdef int width,height
        cdef AVCodecContext *pCodecCtx = self.CodecCtx

        if (pixformat==-1):
            pixformat=self.pixel_format

        pFramePixFormat = avcodec_alloc_frame()
        if pFramePixFormat == NULL:
            raise MemoryError("Unable to allocate Frame")

        width = self.dest_width
        height = self.dest_height
        avpicture_fill(<AVPicture *>pFramePixFormat, <uint8_t *>buf, self.pixel_format,   width, height)
        sws_scale(self.convert_ctx, frame.data, frame.linesize, 0, self.height, <uint8_t**>pFramePixFormat.data, pFramePixFormat.linesize)
        return pFramePixFormat


    # #########################################################
    # time  related functions
    # #########################################################

    def get_fps(self):
        """ return the number of frame per second of the video """
        return (<float>self.stream.r_frame_rate.num / <float>self.stream.r_frame_rate.den)

    def get_base_freq(self):
        """ return the base frequency of a file """
        return (<float>self.CodecCtx.time_base.den/<float>self.CodecCtx.time_base.num)

    def seek_to_frame(self, fno):
        fps=self.get_fps()
        dst=float(fno)/fps
        #sys.stderr.write( "seeking to %f seconds (fps=%f)\n"%(dst,fps))
        self.seek_to_seconds(dst)

    #        def GetFrameTime(self, timestamp):
    #           cdef int64_t targetPts
    #           targetPts = timestamp * AV_TIME_BASE
    #           return self.GetFramePts(targetPts)

    def safe_smallest_videobank_time(self):
        try:
            return self.smallest_videobank_time()
        except:
            self.__next_frame()
            return self.smallest_videobank_time()

    def get_current_frame_pts(self):
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][0]

    def get_current_frame_frameno(self):
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][1]

    def get_current_frame_type(self):
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][3]

    def _get_current_frame_frameno(self):
        return self.CodecCtx.frame_number


    #def write_picture():
        #cdef int out_size
        #if (self.cframe == None):
                #self.CodecCtx.bit_rate = self.bitrate;
                #self.CodecCtx.width = self.width;
                #self.CodecCtx.height = self.height;
                #CodecCtx.frame_rate = (int)self.frate;
                #c->frame_rate_base = 1;
                #c->gop_size = self.gop;
                #c->me_method = ME_EPZS;

                #if (avcodec_open(c, codec) < 0):
                #        raise Exception, "Could not open codec"

                # Write header
                #av_write_header(self.oc);

                # alloc image and output buffer
                #pict = &pic1;
                #avpicture_alloc(pict,PIX_FMT_YUV420P, c->width,c->height);

                #outbuf_size = 1000000;
                #outbuf = "\0"*outbuf_size
                #avframe->linesize[0]=c->width*3;


        #avframe->data[0] = pixmap_;

        ### TO UPDATE
        #img_convert(pict,PIX_FMT_YUV420P, (AVPicture*)avframe, PIX_FMT_RGB24,c->width, c->height);


        ## ENCODE
        #out_size = avcodec_encode_video(c, outbuf, outbuf_size, (AVFrame*)pict);

        #if (av_write_frame(oc, 0, outbuf, out_size)):
        #        raise Exception, "Error while encoding picture"
        #cframe+=1


###############################################################################
## The Reader Class
###############################################################################

cdef class FFMpegReader(AFFMpegReader):
    """ A reader is responsible for playing the file demultiplexing it, and
        to passing the data of each stream to the corresponding track object.

    """
    cdef object default_audio_track
    cdef object default_video_track
    cdef int with_readahead
    cdef unsigned long long int seek_before_security_interval

    def __new__(self,with_readahead=True,seek_before=4000):
        self.filename = None
        self.tracks=[]
        self.ctracks=NULL
        self.FormatCtx=NULL
        self.io_context=NULL
        self.frameno = 0
        self.pts=0
        self.dts=0
        self.altpacket=0
        self.prepacket=<AVPacket *>None
        self.packet=&self.packetbufa
        self.observers_enabled=True
        self.errjmppts=0
        self.default_audio_track=None
        self.default_video_track=None
        self.with_readahead=with_readahead
        self.seek_before_security_interval=seek_before

    def __dealloc__(self):
        self.tracks=[]
        if (self.FormatCtx!=NULL):
            if (self.packet):
                av_free_packet(self.packet)
                self.packet=NULL
            if (self.prepacket):
                av_free_packet(self.prepacket)
                self.prepacket=NULL
            av_close_input_file(self.FormatCtx)
            self.FormatCtx=NULL

    def __del__(self):
        self.close()

    def dump(self):
        dump_format(self.FormatCtx,0,self.filename,0)

    #def open_old(self,char *filename,track_selector=None,mode="r"):

        #
        # Open the Multimedia File
        #

#        ret = av_open_input_file(&self.FormatCtx,filename,NULL,0,NULL)
#        if ret != 0:
#            raise IOError("Unable to open file %s" % filename)
#        self.filename = filename
#        if (mode=="r"):
#            self.__finalize_open(track_selector)
#        else:
#            self.__finalize_open_write()




    def open(self,char *filename,track_selector=None,mode="r",buf_size=1024):
        cdef int ret
        cdef int score
        cdef AVInputFormat * fmt
        cdef AVProbeData pd
        fmt=NULL
        pd.filename=filename
        pd.buf=NULL
        pd.buf_size=0

        self.filename = filename
        self.FormatCtx = avformat_alloc_context()

        if (mode=="w"):
            raise Exception,"Not yet supported sorry"
            self.FormatCtx.oformat = guess_format(NULL, filename_, NULL);
            if (self.FormatCtx.oformat==NULL):
                raise Exception, "Unable to find output format for %s\n"


        #self.FormatCtx.priv_data = av_mallocz(self.FormatCtx.oformat.priv_data_size);
        if (fmt==NULL):
            fmt=av_probe_input_format(&pd,0)
        #//print (<long>fmt)
        if (fmt==NULL) or (not (fmt.flags & AVFMT_NOFILE)):
            ret=url_fopen(&self.FormatCtx.pb, filename, 0)
            if ret < 0:
                raise IOError("Unable to open file %s (url_fopen)" % filename)
            if (buf_size>0):
                url_setbufsize(self.FormatCtx.pb,buf_size)
            #raise Exception, "Not Yet Implemented"
            for log2_probe_size in range(11,20):
                probe_size=1<<log2_probe_size
                #score=(AVPROBE_SCORE_MAX/4 if log2_probe_size!=20 else 0)
                pd.buf=<unsigned char *>av_realloc(pd.buf,probe_size+AVPROBE_PADDING_SIZE)
                pd.buf_size=get_buffer(self.FormatCtx.pb,pd.buf,probe_size)
                memset(pd.buf+pd.buf_size,0,AVPROBE_PADDING_SIZE)
                if (url_fseek(self.FormatCtx.pb,0,SEEK_SET)):
                    url_fclose(self.FormatCtx.pb)
                    ret=url_fopen(&self.FormatCtx.pb, filename, 0)
                    if (ret < 0):
                        raise IOError("Unable to open file %s (url_fopen with but)" % filename)
                fmt=av_probe_input_format(&pd,1)#,&score)
                if (fmt!=NULL):
                    break

        assert(fmt!=NULL)
        self.FormatCtx.iformat=fmt


        if (mode=="r"):
            ret = av_open_input_stream(&self.FormatCtx,self.FormatCtx.pb,filename,self.FormatCtx.iformat,NULL)
            if ret != 0:
                raise IOError("Unable to open stream %s" % filename)
            self.__finalize_open(track_selector)
        elif (mode=="w"):
            ret=url_fopen(&self.FormatCtx.pb, filename, 1)
            if ret != 0:
                raise IOError("Unable to open file %s" % filename)
            self.__finalize_open_write()
        else:
            raise ValueError, "Unknown Mode"




    def __finalize_open_write(self):
        """
         EXPERIMENTAL !
        """
        cdef  AVFormatContext * oc
        oc = avformat_alloc_context()
        # Guess file format with file extention
        oc.oformat = guess_format(NULL, filename_, NULL);
        if (oc.oformat==NULL):
            raise Exception, "Unable to find output format for %s\n"
        # Alloc priv_data for format
        oc.priv_data = av_mallocz(oc.oformat.priv_data_size);
        #avframe = avcodec_alloc_frame();



        # Create the video stream on output AVFormatContext oc
        #self.st = av_new_stream(oc,0)
        # Alloc the codec to the new stream
        #c = &self.st.codec
        # find the video encoder

        #codec = avcodec_find_encoder(oc.oformat.video_codec);
        #if (self.st.codec==None):
        #    raise Exception,"codec not found\n"
        #codec_name = <char *> codec.name;

        # Create the output file
        url_fopen(&oc.pb, filename_, URL_WRONLY)

        # last part of init will be set when first frame write()
        # because we need user parameters like size, bitrate...
        self.mode = "w"


    def __finalize_open(self, track_selector=None):
        cdef AVCodecContext * CodecCtx
        cdef VideoTrack vt
        cdef AudioTrack at
        cdef int ret
        cdef int i

        if (track_selector==None):
            track_selector=TS_VIDEO
        ret = av_find_stream_info(self.FormatCtx)
        if ret < 0:
            raise IOError("Unable to find Track info: %d" % (ret,))


        self.pts=0
        self.dts=0

        self.altpacket=0
        self.prepacket=<AVPacket *>None
        self.packet=&self.packetbufa
        #
        # Open the selected Track
        #


        #for i in range(self.FormatCtx.nb_streams):
        #  print "stream #",i," codec_type:",self.FormatCtx.streams[i].codec.codec_type

        for s in track_selector.values():
            #print s
            trackno = -1
            trackb=s[1]
            if (trackb<0):
                for i in range(self.FormatCtx.nb_streams):
                    if self.FormatCtx.streams[i].codec.codec_type == s[0]:
                        if (trackb!=-1):
                            trackb+=1
                        else:
                            #DEBUG("associated "+str(s)+" to "+str(i))
                            #sys.stdin.readline()
                            trackno = i
                            break
            else:
                trackno=s[1]
                assert(trackno<self.FormatCtx.nb_streams)
                assert(self.FormatCtx.streams[i].codec.codec_type == s[0])
            if trackno == -1:
                raise IOError("Unable to find specified Track")

            CodecCtx = self.FormatCtx.streams[trackno].codec
            if (s[0]==CODEC_TYPE_VIDEO):
                try:
                    vt=VideoTrack()
                except:
                    vt=VideoTrack(support_truncated=1)
                if (self.default_video_track==None):
                    self.default_video_track=vt
                vt.init0(self,trackno,  CodecCtx) ## here we are passing cpointers so we do a C call
                vt.init(**s[2])## here we do a python call
                self.tracks.append(vt)
            elif (s[0]==CODEC_TYPE_AUDIO):
                try:
                    at=AudioTrack()
                except:
                    at=AudioTrack(support_truncated=1)
                if (self.default_audio_track==None):
                    self.default_audio_track=at
                at.init0(self,trackno,  CodecCtx) ## here we are passing cpointers so we do a C call
                at.init(**s[2])## here we do a python call
                self.tracks.append(at)
            else:
                raise "unknown type of Track"
        if (self.default_audio_track!=None and self.default_video_track!=None):
            self.default_audio_track.reset_tps(self.default_video_track.get_fps())
        for t in self.tracks:
            t.check_start() ### this is done only if asked
            savereadahead=self.with_readahead
            savebsi=self.seek_before_security_interval
            self.seek_before_security_interval=0
            self.with_readahead=0
            t.check_end()
            self.with_readahead=savereadahead
            self.seek_before_security_interval=savebsi
        try:
            if (self.tracks[0].duration()<0):
                sys.stderr.write("WARNING : inconsistent file duration %x\n"%(self.tracks[0].duration() ,))
                new_duration=-self.tracks[0].duration()
                self.tracks[0]._set_duration(new_duration)
        except KeyError:
            pass

    def close(self):
        if (self.FormatCtx!=NULL):
            for s in self.tracks:
                s.close()
            if (self.packet):
                av_free_packet(self.packet)
                self.packet=NULL
            if (self.prepacket):
                av_free_packet(self.prepacket)
                self.prepacket=NULL
            self.tracks=[] # break cross references
            av_close_input_file(self.FormatCtx)
            self.FormatCtx=NULL


    cdef __prefetch_packet(self):
        """ this function is used for prefetching a packet
            this is used when we want read until something new happen on a specified channel
        """
        #DEBUG("prefetch_packet")
        ret = av_read_frame(self.FormatCtx,self.prepacket)
        if ret < 0:
            #for xerrcnts in range(5,1000):
            #  if (not self.errjmppts):
            #      self.errjmppts=self.tracks[0].get_cur_pts()
            #  no=self.errjmppts+xerrcnts*(AV_TIME_BASE/50)
            #  sys.stderr.write("Unable to read frame:trying to skip some packet and trying again.."+str(no)+","+str(xerrcnts)+"...\n")
            #  av_seek_frame(self.FormatCtx,-1,no,0)
            #  ret = av_read_frame(self.FormatCtx,self.prepacket)
            #  if (ret!=-5):
            #      self.errjmppts=no
            #      print "solved : ret=",ret
            #      break
            #if ret < 0:
            raise IOError("Unable to read frame: %d" % (ret,))
        #DEBUG("/prefetch_packet")

    cdef read_packet_buggy(self):
        """
         This function is supposed to make things nicer...
         However, it is buggy right now and I have to check
         whether it is sitll necessary... So it will be re-enabled ontime...
        """
        cdef bint packet_processed=False
        #DEBUG("read_packet %d %d"%(long(<long int>self.packet),long(<long int>self.prepacket)))
        while not packet_processed:
                #ret = av_read_frame(self.FormatCtx,self.packet)
                #if ret < 0:
                #    raise IOError("Unable to read frame: %d" % (ret,))
            if (self.prepacket==<AVPacket *>None):
                self.prepacket=&self.packetbufa
                self.packet=&self.packetbufb
                self.__prefetch_packet()
            self.packet=self.prepacket
            if (self.packet==&self.packetbufa):
                self.prepacket=&self.packetbufb
            else:
                self.prepacket=&self.packetbufa
            #DEBUG("...PRE..")
            self.__prefetch_packet()
            #DEBUG("packets %d %d"%(long(<long int>self.packet),long(<long int>self.prepacket)))
            packet_processed=self.process_current_packet()
        #DEBUG("/read_packet")

    cdef read_packet(self):
        self.prepacket=&self.packetbufb
        ret = av_read_frame(self.FormatCtx,self.prepacket)
        if ret < 0:
            raise IOError("Unable to read frame: %d" % (ret,))
        self.packet=self.prepacket
        packet_processed=self.process_current_packet()


    def process_current_packet(self):
        """ This function implements the demuxes.
            It dispatch the packet to the correct track processor.

            Limitation : TODO: This function is to be improved to support more than audio and  video tracks.
        """
        cdef Track ct
        cdef VideoTrack vt
        cdef AudioTrack at
        #DEBUG("process_current_packet")
        processed=False
        for s in self.tracks:
            ct=s ## does passing through a pointer solves virtual issues...
            #DEBUG("track : %s = %s ??" %(ct.no,self.packet.stream_index))
            if (ct.no==self.packet.stream_index):
                #ct.process_packet(self.packet)
                ## I don't know why it seems that Windows Cython have problem calling the correct virtual function
                ##
                ##
                if ct.CodecCtx.codec_type==CODEC_TYPE_VIDEO:
                    processed=True
                    vt=ct
                    vt.process_packet(self.packet)
                elif ct.CodecCtx.codec_type==CODEC_TYPE_AUDIO:
                    processed=True
                    at=ct
                    at.process_packet(self.packet)
                else:
                    raise Exception, "Unknown codec type"
                    #ct.process_packet(self.packet)
                #DEBUG("/process_current_packet (ok)")
                av_free_packet(self.packet)
                self.packet=NULL
                return True
        #DEBUG("A packet tageted to track %d has not been processed..."%(self.packet.stream_index))
        #DEBUG("/process_current_packet (not processed !!)")
        av_free_packet(self.packet)
        self.packet=NULL
        return False

    def disable_observers(self):
        self.observers_enabled=False

    def enable_observers(self):
        self.observers_enabled=True

    def get_current_frame(self):
        r=[]
        for tt in self.tracks:
            r.append(tt.get_current_frame())
        return r

    def get_next_frame(self):
        self.tracks[0].get_next_frame()
        return self.get_current_frame()

    def __len__(self):
        try:
            return len(self.tracks[0])
        except:
            raise IOError,"File not correctly opened"


    def read_until_next_frame(self, calltrack=0,maxerrs=10, maxread=10):
        """ read all packets until a frame for the Track "calltrack" arrives """
        #DEBUG("read untiil next fame")
        try :
            while ((maxread>0)  and (calltrack==-1) or (self.prepacket.stream_index != (self.tracks[calltrack].get_no()))):
                if (self.prepacket==<AVPacket *>None):
                    self.prepacket=&self.packetbufa
                    self.packet=&self.packetbufb
                    self.__prefetch_packet()
                self.packet=self.prepacket
                cont=True
                #DEBUG("read until next frame iteration ")
                while (cont):
                    try:
                        self.__prefetch_packet()
                        cont=False
                    except KeyboardInterrupt:
                        raise
                    except:
                        maxerrs-=1
                        if (maxerrs<=0):
                            #DEBUG("read until next frame MAX ERR COUNTS REACHED... Raising Exception")
                            raise
                self.process_current_packet()
                maxread-=1
        except Queue_Full:
            #DEBUG("/read untiil next frame : QF")
            return False
        except IOError:
            #DEBUG("/read untiil next frame : IOError")
            sys.stderr.write("IOError")
            return False
        #DEBUG("/read until next frame")
        return True


    def get_tracks(self):
        return self.tracks


    def seek_to(self, pts):
        """
          Globally seek on all the streams to a specified position.
        """
        #sys.stderr.write("Seeking to PTS=%d\n"%pts)
        cdef int ret=0
        #av_read_frame_flush(self.FormatCtx)
        #DEBUG("FLUSHED")
        ppts=pts-self.seek_before_security_interval # seek a little bit before... and then manually go direct frame
        #ppts=pts
        #print ppts, pts
        #DEBUG("CALLING AV_SEEK_FRAME")

        #try:
        #  if (pts > self.tracks[0].duration()):
        #        raise IOError,"Cannot seek after the end...\n"
        #except KeyError:
        #  pass


        ret = av_seek_frame(self.FormatCtx,-1,ppts,  AVSEEK_FLAG_BACKWARD)#|AVSEEK_FLAG_ANY)
        #DEBUG("AV_SEEK_FRAME DONE")
        if ret < 0:
            raise IOError("Unable to seek: %d" % ret)
        #if (self.io_context!=NULL):
        #    #DEBUG("using FSEEK  ")
        #    #used to have & on pb
        # url_fseek(self.FormatCtx.pb, self.FormatCtx.data_offset, SEEK_SET);
        ## ######################################
        ## Flush buffer
        ## ######################################

        #DEBUG("resetting track buffers")
        for  s in self.tracks:
            s.reset_buffers()

        ## ######################################
        ## do set up exactly all tracks
        ## ######################################

        try:
            if (self.seek_before_security_interval):
            #DEBUG("finalize seek    ")
                self.disable_observers()
                self._finalize_seek_to(pts)
                self.enable_observers()
        except KeyboardInterrupt:
            raise
        except:
            DEBUG("Exception during finalize_seek")

        ## ######################################
        ## read ahead buffers
        ## ######################################
        if self.with_readahead:
            try:
                #DEBUG("readahead")
                self.prepare_to_read_ahead()
                #DEBUG("/readahead")
            except KeyboardInterrupt:
                raise
            except:
                DEBUG("Exception during read ahead")


        #DEBUG("/seek")

    def reset_buffers(self):
        for  s in self.tracks:
            s.reset_buffers()

    def _finalize_seek_to(self, pts):
        """
            This internal function set the player in a correct state after by waiting for information that
            happen after a specified PTS to effectively occur.
        """
        while(self.tracks[0].get_cur_pts()<pts):
            #sys.stderr.write("approx PTS:" + str(self.tracks[0].get_cur_pts())+"\n")
            #print "approx pts:", self.tracks[0].get_cur_pts()
            self.step()
        sys.stderr.write("result PTS:" + str(self.tracks[0].get_cur_pts())+"\n")
        #sys.stderr.write("result PTR hex:" + hex(self.tracks[0].get_cur_pts())+"\n")

    def seek_bytes(self, byte):
        cdef int ret=0
        av_read_frame_flush(self.FormatCtx);
        ret = av_seek_frame(self.FormatCtx,-1,byte,  AVSEEK_FLAG_BACKWARD|AVSEEK_FLAG_BYTE)#|AVSEEK_FLAG_ANY)
        if ret < 0:
            raise IOError("Unable to seek: %d" % (ret,))
        if (self.io_context!=NULL):
            # used to have & here
            url_fseek(self.FormatCtx.pb, self.FormatCtx.data_offset, SEEK_SET);
        ## ######################################
        ## Flush buffer
        ## ######################################


        if (self.packet):
            av_free_packet(self.packet)
            self.packet=NULL
        self.altpacket=0
        self.prepacket=<AVPacket *>None
        self.packet=&self.packetbufa
        for  s in self.tracks:
            s.reset_buffers()

        ## ##########################################################
        ## Put the buffer in a states that would make reading easier
        ## ##########################################################
        self.prepare_to_read_ahead()


    def __getitem__(self,int pos):
        fps=self.tracks[0].get_fps()
        self.seek_to((pos/fps)*AV_TIME_BASE)
        #sys.stderr.write("Trying to get frame\n")
        ri=self.get_current_frame()
        #sys.stderr.write("Ok\n")
        #sys.stderr.write("ri=%s\n"%(repr(ri)))
        return ri

    def prepare_to_read_ahead(self):
        """ fills in all buffers in the tracks so that all necessary datas are available"""
        for  s in self.tracks:
            s.prepare_to_read_ahead()

    def step(self):
        self.tracks[0].get_next_frame()

    def run(self):
        while True:
            #DEBUG("PYFFMPEG RUN : STEP")
            self.step()

    def print_buffer_stats(self):
        c=0
        for t in self.tracks():
            print "track ",c
            try:
                t.print_buffer_stats
            except KeyboardInterrupt:
                raise
            except:
                pass
            c=c+1

    def duration(self):
        if (self.FormatCtx.duration==0x8000000000000000):
            raise KeyError
        return self.FormatCtx.duration

    def duration_time(self):
        return float(self.duration())/ (<float>AV_TIME_BASE)


#cdef class FFMpegStreamReader(FFMpegReader):
   # """
   # This contains some experimental code not meant to be used for the moment
    #"""
#    def open_url(self,  char *filename,track_selector=None):
#        cdef AVInputFormat *format
#        cdef AVProbeData probe_data
#        cdef unsigned char tbuffer[65536]
#        cdef unsigned char tbufferb[65536]

        #self.io_context=av_alloc_put_byte(tbufferb, 65536, 0,<void *>0,<void *>0,<void *>0,<void *>0)  #<ByteIOContext*>PyMem_Malloc(sizeof(ByteIOContext))
        #IOString ios
#       URL_RDONLY=0
#        if (url_fopen(&self.io_context, filename,URL_RDONLY ) < 0):
#            raise IOError, "unable to open URL"
#        print "Y"

#        url_fseek(self.io_context, 0, SEEK_SET);

#        probe_data.filename = filename;
#        probe_data.buf = tbuffer;
#        probe_data.buf_size = 65536;

        #probe_data.buf_size = get_buffer(&io_context, buffer, sizeof(buffer));
        #

#        url_fseek(self.io_context, 65535, SEEK_SET);
        #
        #format = av_probe_input_format(&probe_data, 1);
        #
        #            if (not format) :
        #                url_fclose(&io_context);
        #                raise IOError, "unable to get format for URL"

#        if (av_open_input_stream(&self.FormatCtx, self.io_context, NULL, NULL, NULL)) :
#            url_fclose(self.io_context);
#            raise IOError, "unable to open input stream"
#        self.filename = filename
#        self.__finalize_open(track_selector)
#        print "Y"




###############################################################################################
##  compatibility with previous PyFFMPEG version
###############################################################################################


class VideoStream:
    def __init__(self):
        self.vr=FFMpegReader()
    def __del__(self):
        self.close()
    def open(self, *args, ** xargs ):
        xargs["track_selector"]=TS_VIDEO_PIL
        self.vr.open(*args, **xargs)
        self.tv=self.vr.get_tracks()[0]
    def close(self):
        self.vr.close()
        self.vr=None
    def GetFramePts(self, pts):
        self.tv.seek_to_pts(pts)
        return self.tv.get_current_frame()[2]
    def GetFrameNo(self, fno):
        self.tv.seek_to_frame(fno)
        return self.tv.get_current_frame()[2]
    def GetCurrentFrame(self, fno):
        return self.tv.get_current_frame()[2]
    def GetNextFrame(self, fno):
        return self.tv.get_next_frame()


##
## usefull constants
##
class PixelFormats:
    NONE= -1
    YUV420P=0
    YUYV422=1
    RGB24=2
    BGR24=3
    YUV422P=4
    YUV444P=5
    YUV410P=6
    YUV411P=7
    GRAY8=8
    MONOWHITE=9
    MONOBLACK=10
    YUVJ420P=11
    YUVJ422P=12
    YUVJ444P=13
    XVMC_MPEG2_MC=14
    XVMC_MPEG2_IDCT=15
    UYVY422=16
    UYYVYY411=17
    BGR8=18
    BGR4=19
    BGR4_BYTE=20
    RGB8=21
    RGB4=22
    RGB4_BYTE=23
    NV12=24
    NV21=25
    ARGB=27
    RGBA=28
    ABGR=29
    BGRA=30
    GRAY16BE=31
    GRAY16LE=32
