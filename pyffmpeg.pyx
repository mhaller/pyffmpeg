# -*- coding: utf-8 -*-

"""
##################################################################################
# PyFFmpeg v2.2 alpha 1
#
# Copyright (C) 2011 Martin Haller <martin.haller@computer.org>
# Copyright (C) 2011 Bertrand Nouvel <bertrand@lm3labs.com>
# Copyright (C) 2008-2010 Bertrand Nouvel <nouvel@nii.ac.jp>
#   Japanese French Laboratory for Informatics -  CNRS
#
##################################################################################
#  This file is distibuted under LGPL-3.0
#  See COPYING file attached.
##################################################################################
#
#    TODO:
#       * check motion vector related functions
#       * why seek_before mandatory
#       * Add support for video encoding
#       * add multithread support
#       * Fix first frame bug... 
#
#    Abilities
#     * Frame seeking (TO BE CHECKED again and again)
#
#    Changed compared with PyFFmpeg version 1.0:
#     * Clean up destructors
#     * Added compatibility with NumPy and PIL
#     * Added copyless mode for ordered streams/tracks ( when buffers are disabled)
#     * Added audio support
#     * MultiTrack support (possibility to pass paramer)
#     * Added support for streamed video
#     * Updated ID for compatibility with transparency
#     * Updated to latest avcodec primitives
#
##################################################################################
# Based on Pyffmpeg 0.2 by
# Copyright (C) 2006-2007 James Evans <jaevans@users.sf.net>
# Authorization to change from GPL2.0 to LGPL 3.0 provided by original author for 
# this new version
##################################################################################
"""

##################################################################################
# Settings
##################################################################################
AVCODEC_MAX_AUDIO_FRAME_SIZE=192000
AVPROBE_PADDING_SIZE=32
OUTPUTMODE_NUMPY=0
OUTPUTMODE_PIL=1


##################################################################################
#  Declaration and imports
##################################################################################
import sys
import traceback


##################################################################################
# ffmpeg uses following integer types
ctypedef signed char int8_t
ctypedef unsigned char uint8_t
ctypedef signed short int16_t
ctypedef unsigned short uint16_t
ctypedef signed long int32_t
ctypedef unsigned long uint32_t
ctypedef signed long long int64_t
ctypedef unsigned long long uint64_t


##################################################################################
cdef enum:
    SEEK_SET = 0
    SEEK_CUR = 1
    SEEK_END = 2


##################################################################################
cdef extern from "string.h":
    memcpy(void * dst, void * src, unsigned long sz)
    memset(void * dst, unsigned char c, unsigned long sz)


##################################################################################
cdef extern from "Python.h":
    ctypedef int size_t
    object PyBuffer_FromMemory( void *ptr, int size)
    object PyBuffer_FromReadWriteMemory( void *ptr, int size)
    object PyString_FromStringAndSize(char *s, int len)
    void* PyMem_Malloc( size_t n)
    void PyMem_Free( void *p)


##################################################################################
# ok libavutil    50. 39. 0 
cdef extern from "libavutil/mathematics.h":
    int64_t av_rescale(int64_t a, int64_t b, int64_t c)


##################################################################################
# ok libavutil    50. 39. 0
cdef extern from "libavutil/mem.h":
    # size_t is used 
    #ctypedef unsigned long FF_INTERNAL_MEM_TYPE
    ctypedef size_t FF_INTERNAL_MEM_TYPE
    void *av_mallocz(FF_INTERNAL_MEM_TYPE size)
    void *av_realloc(void * ptr, FF_INTERNAL_MEM_TYPE size)
    void av_free(void *ptr)
    void av_freep(void *ptr)
    
    
##################################################################################
# ok libavutil    50. 39. 0
cdef extern from "libavutil/pixfmt.h":
    cdef enum PixelFormat:
        PIX_FMT_NONE= -1,
        PIX_FMT_YUV420P,   #< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
        PIX_FMT_YUYV422,   #< packed YUV 4:2:2, 16bpp, Y0 Cb Y1 Cr
        PIX_FMT_RGB24,     #< packed RGB 8:8:8, 24bpp, RGBRGB...
        PIX_FMT_BGR24,     #< packed RGB 8:8:8, 24bpp, BGRBGR...
        PIX_FMT_YUV422P,   #< planar YUV 4:2:2, 16bpp, (1 Cr & Cb sample per 2x1 Y samples)
        PIX_FMT_YUV444P,   #< planar YUV 4:4:4, 24bpp, (1 Cr & Cb sample per 1x1 Y samples)
        PIX_FMT_YUV410P,   #< planar YUV 4:1:0,  9bpp, (1 Cr & Cb sample per 4x4 Y samples)
        PIX_FMT_YUV411P,   #< planar YUV 4:1:1, 12bpp, (1 Cr & Cb sample per 4x1 Y samples)
        PIX_FMT_GRAY8,     #<        Y        ,  8bpp
        PIX_FMT_MONOWHITE, #<        Y        ,  1bpp, 0 is white, 1 is black, in each byte pixels are ordered from the msb to the lsb
        PIX_FMT_MONOBLACK, #<        Y        ,  1bpp, 0 is black, 1 is white, in each byte pixels are ordered from the msb to the lsb
        PIX_FMT_PAL8,      #< 8 bit with PIX_FMT_RGB32 palette
        PIX_FMT_YUVJ420P,  #< planar YUV 4:2:0, 12bpp, full scale (JPEG), deprecated in favor of PIX_FMT_YUV420P and setting color_range
        PIX_FMT_YUVJ422P,  #< planar YUV 4:2:2, 16bpp, full scale (JPEG), deprecated in favor of PIX_FMT_YUV422P and setting color_range
        PIX_FMT_YUVJ444P,  #< planar YUV 4:4:4, 24bpp, full scale (JPEG), deprecated in favor of PIX_FMT_YUV444P and setting color_range
        PIX_FMT_XVMC_MPEG2_MC,#< XVideo Motion Acceleration via common packet passing
        PIX_FMT_XVMC_MPEG2_IDCT,
        PIX_FMT_UYVY422,   #< packed YUV 4:2:2, 16bpp, Cb Y0 Cr Y1
        PIX_FMT_UYYVYY411, #< packed YUV 4:1:1, 12bpp, Cb Y0 Y1 Cr Y2 Y3
        PIX_FMT_BGR8,      #< packed RGB 3:3:2,  8bpp, (msb)2B 3G 3R(lsb)
        PIX_FMT_BGR4,      #< packed RGB 1:2:1 bitstream,  4bpp, (msb)1B 2G 1R(lsb), a byte contains two pixels, the first pixel in the byte is the one composed by the 4 msb bits
        PIX_FMT_BGR4_BYTE, #< packed RGB 1:2:1,  8bpp, (msb)1B 2G 1R(lsb)
        PIX_FMT_RGB8,      #< packed RGB 3:3:2,  8bpp, (msb)2R 3G 3B(lsb)
        PIX_FMT_RGB4,      #< packed RGB 1:2:1 bitstream,  4bpp, (msb)1R 2G 1B(lsb), a byte contains two pixels, the first pixel in the byte is the one composed by the 4 msb bits
        PIX_FMT_RGB4_BYTE, #< packed RGB 1:2:1,  8bpp, (msb)1R 2G 1B(lsb)
        PIX_FMT_NV12,      #< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are interleaved (first byte U and the following byte V)
        PIX_FMT_NV21,      #< as above, but U and V bytes are swapped
    
        PIX_FMT_ARGB,      #< packed ARGB 8:8:8:8, 32bpp, ARGBARGB...
        PIX_FMT_RGBA,      #< packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
        PIX_FMT_ABGR,      #< packed ABGR 8:8:8:8, 32bpp, ABGRABGR...
        PIX_FMT_BGRA,      #< packed BGRA 8:8:8:8, 32bpp, BGRABGRA...
    
        PIX_FMT_GRAY16BE,  #<        Y        , 16bpp, big-endian
        PIX_FMT_GRAY16LE,  #<        Y        , 16bpp, little-endian
        PIX_FMT_YUV440P,   #< planar YUV 4:4:0 (1 Cr & Cb sample per 1x2 Y samples)
        PIX_FMT_YUVJ440P,  #< planar YUV 4:4:0 full scale (JPEG), deprecated in favor of PIX_FMT_YUV440P and setting color_range
        PIX_FMT_YUVA420P,  #< planar YUV 4:2:0, 20bpp, (1 Cr & Cb sample per 2x2 Y & A samples)
        PIX_FMT_VDPAU_H264,#< H.264 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        PIX_FMT_VDPAU_MPEG1,#< MPEG-1 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        PIX_FMT_VDPAU_MPEG2,#< MPEG-2 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        PIX_FMT_VDPAU_WMV3,#< WMV3 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        PIX_FMT_VDPAU_VC1, #< VC-1 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        PIX_FMT_RGB48BE,   #< packed RGB 16:16:16, 48bpp, 16R, 16G, 16B, the 2-byte value for each R/G/B component is stored as big-endian
        PIX_FMT_RGB48LE,   #< packed RGB 16:16:16, 48bpp, 16R, 16G, 16B, the 2-byte value for each R/G/B component is stored as little-endian
    
        PIX_FMT_RGB565BE,  #< packed RGB 5:6:5, 16bpp, (msb)   5R 6G 5B(lsb), big-endian
        PIX_FMT_RGB565LE,  #< packed RGB 5:6:5, 16bpp, (msb)   5R 6G 5B(lsb), little-endian
        PIX_FMT_RGB555BE,  #< packed RGB 5:5:5, 16bpp, (msb)1A 5R 5G 5B(lsb), big-endian, most significant bit to 0
        PIX_FMT_RGB555LE,  #< packed RGB 5:5:5, 16bpp, (msb)1A 5R 5G 5B(lsb), little-endian, most significant bit to 0
    
        PIX_FMT_BGR565BE,  #< packed BGR 5:6:5, 16bpp, (msb)   5B 6G 5R(lsb), big-endian
        PIX_FMT_BGR565LE,  #< packed BGR 5:6:5, 16bpp, (msb)   5B 6G 5R(lsb), little-endian
        PIX_FMT_BGR555BE,  #< packed BGR 5:5:5, 16bpp, (msb)1A 5B 5G 5R(lsb), big-endian, most significant bit to 1
        PIX_FMT_BGR555LE,  #< packed BGR 5:5:5, 16bpp, (msb)1A 5B 5G 5R(lsb), little-endian, most significant bit to 1
    
        PIX_FMT_VAAPI_MOCO, #< HW acceleration through VA API at motion compensation entry-point, Picture.data[3] contains a vaapi_render_state struct which contains macroblocks as well as various fields extracted from headers
        PIX_FMT_VAAPI_IDCT, #< HW acceleration through VA API at IDCT entry-point, Picture.data[3] contains a vaapi_render_state struct which contains fields extracted from headers
        PIX_FMT_VAAPI_VLD,  #< HW decoding through VA API, Picture.data[3] contains a vaapi_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
    
        PIX_FMT_YUV420P16LE,  #< planar YUV 4:2:0, 24bpp, (1 Cr & Cb sample per 2x2 Y samples), little-endian
        PIX_FMT_YUV420P16BE,  #< planar YUV 4:2:0, 24bpp, (1 Cr & Cb sample per 2x2 Y samples), big-endian
        PIX_FMT_YUV422P16LE,  #< planar YUV 4:2:2, 32bpp, (1 Cr & Cb sample per 2x1 Y samples), little-endian
        PIX_FMT_YUV422P16BE,  #< planar YUV 4:2:2, 32bpp, (1 Cr & Cb sample per 2x1 Y samples), big-endian
        PIX_FMT_YUV444P16LE,  #< planar YUV 4:4:4, 48bpp, (1 Cr & Cb sample per 1x1 Y samples), little-endian
        PIX_FMT_YUV444P16BE,  #< planar YUV 4:4:4, 48bpp, (1 Cr & Cb sample per 1x1 Y samples), big-endian
        PIX_FMT_VDPAU_MPEG4,  #< MPEG4 HW decoding with VDPAU, data[0] contains a vdpau_render_state struct which contains the bitstream of the slices as well as various fields extracted from headers
        PIX_FMT_DXVA2_VLD,    #< HW decoding through DXVA2, Picture.data[3] contains a LPDIRECT3DSURFACE9 pointer
    
        PIX_FMT_RGB444BE,  #< packed RGB 4:4:4, 16bpp, (msb)4A 4R 4G 4B(lsb), big-endian, most significant bits to 0
        PIX_FMT_RGB444LE,  #< packed RGB 4:4:4, 16bpp, (msb)4A 4R 4G 4B(lsb), little-endian, most significant bits to 0
        PIX_FMT_BGR444BE,  #< packed BGR 4:4:4, 16bpp, (msb)4A 4B 4G 4R(lsb), big-endian, most significant bits to 1
        PIX_FMT_BGR444LE,  #< packed BGR 4:4:4, 16bpp, (msb)4A 4B 4G 4R(lsb), little-endian, most significant bits to 1
        PIX_FMT_Y400A,     #< 8bit gray, 8bit alpha
        PIX_FMT_NB         #< number of pixel formats, DO NOT USE THIS if you want to link with shared libav* because the number of formats might differ between versions


##################################################################################
# ok libavutil    50. 39. 0
cdef extern from "libavutil/avutil.h":
    # from avutil.h
    enum AVMediaType:
        AVMEDIA_TYPE_UNKNOWN = -1,
        AVMEDIA_TYPE_VIDEO,
        AVMEDIA_TYPE_AUDIO,
        AVMEDIA_TYPE_DATA,
        AVMEDIA_TYPE_SUBTITLE,
        AVMEDIA_TYPE_ATTACHMENT,
        AVMEDIA_TYPE_NB

    # unnamed enum for defines
    enum:        
        AV_NOPTS_VALUE = <int64_t>0x8000000000000000
        AV_TIME_BASE = 1000000

    # this is defined below as variable
    # AV_TIME_BASE_Q          (AVRational){1, AV_TIME_BASE}


##################################################################################
# ok libavutil    50. 39. 0
cdef extern from "libavutil/samplefmt.h":
    enum AVSampleFormat:
        AV_SAMPLE_FMT_NONE = -1,
        AV_SAMPLE_FMT_U8,          #< unsigned 8 bits
        AV_SAMPLE_FMT_S16,         #< signed 16 bits
        AV_SAMPLE_FMT_S32,         #< signed 32 bits
        AV_SAMPLE_FMT_FLT,         #< float
        AV_SAMPLE_FMT_DBL,         #< double
        AV_SAMPLE_FMT_NB           #< Number of sample formats. DO NOT USE if dynamically linking to libavcore


##################################################################################
# ok libavutil    50. 39. 0
cdef extern from "libavutil/rational.h":
    struct AVRational:
        int num                    #< numerator
        int den                    #< denominator


##################################################################################
# ok libavformat  52.102. 0 
cdef extern from "libavformat/avio.h":
    
    struct AVIOContext:
        unsigned char *buffer
        int buffer_size
        unsigned char *buf_ptr, *buf_end
        void *opaque
        int *read_packet
        int *write_packet
        int64_t *seek
        int64_t pos #< position in the file of the current buffer 
        int must_flush #< true if the next seek should flush 
        int eof_reached #< true if eof reached 
        int write_flag  #< true if open for writing 
        int is_streamed
        int max_packet_size
        unsigned long checksum
        unsigned char *checksum_ptr
        unsigned long *update_checksum
        int error         #< contains the error code or 0 if no error happened
        int *read_pause
        int64_t *read_seek

    
    int url_setbufsize(AVIOContext *s, int buf_size)
    int url_ferror(AVIOContext *s)
    int avio_open(AVIOContext **s, char *url, int flags)    
    int avio_close(AVIOContext *s)
    int avio_read(AVIOContext *s, unsigned char *buf, int size)
    int64_t avio_seek(AVIOContext *s, int64_t offset, int whence)    
    AVIOContext *avio_alloc_context(
                      unsigned char *buffer,
                      int buffer_size,
                      int write_flag,
                      void *opaque,
                      void *a,
                      void *b,
                      void *c)
    
    #struct ByteIOContext:
    #    pass
    #ctypedef long long int  offset_t

    #int get_buffer(ByteIOContext *s, unsigned char *buf, int size)
    # use avio_read(s, buf, size);
    
    #int url_ferror(ByteIOContext *s)
    # use int url_ferror(AVIOContext *s)

    #int url_feof(ByteIOContext *s)
    # use AVIOContext.eof_reached 
    
    #int url_fopen(ByteIOContext **s,  char *filename, int flags)
    # use avio_open(s, filename, flags);    
    
    #int url_setbufsize(ByteIOContext *s, int buf_size)
    #use int url_setbufsize(AVIOContext *s, int buf_size);

    #int url_fclose(ByteIOContext *s)
    # use avio_close(s)
    
    #long long int url_fseek(ByteIOContext *s, long long int offset, int whence)
    # use avio_seek(s, offset, whence);
    
    #    ByteIOContext *av_alloc_put_byte(
    #                  unsigned char *buffer,
    #                  int buffer_size,
    #                  int write_flag,
    #                  void *opaque,
    #                  void * a , void * b , void * c)
    #                  #int (*read_packet)(void *opaque, uint8_t *buf, int buf_size),
    #                  #int (*write_packet)(void *opaque, uint8_t *buf, int buf_size),
    #                  #offset_t (*seek)(void *opaque, offset_t offset, int whence))
    # use avio_alloc_context(buffer, buffer_size, write_flag, opaque,
    #                           read_packet, write_packet, seek);               
    
    
##################################################################################
# ok libavcodec   52.113. 2
cdef extern from "libavcodec/avcodec.h":
    # use an unamed enum for defines
    cdef enum:
        CODEC_FLAG_QSCALE               = 0x0002  #< Use fixed qscale.
        CODEC_FLAG_4MV                  = 0x0004  #< 4 MV per MB allowed / advanced prediction for H.263.
        CODEC_FLAG_QPEL                 = 0x0010  #< Use qpel MC.
        CODEC_FLAG_GMC                  = 0x0020  #< Use GMC.
        CODEC_FLAG_MV0                  = 0x0040  #< Always try a MB with MV=<0,0>.
        CODEC_FLAG_PART                 = 0x0080  #< Use data partitioning.
        # * The parent program guarantees that the input for B-frames containing
        # * streams is not written to for at least s->max_b_frames+1 frames, if
        # * this is not set the input will be copied.
        CODEC_FLAG_INPUT_PRESERVED      = 0x0100
        CODEC_FLAG_PASS1                = 0x0200   #< Use internal 2pass ratecontrol in first pass mode.
        CODEC_FLAG_PASS2                = 0x0400   #< Use internal 2pass ratecontrol in second pass mode.
        CODEC_FLAG_EXTERN_HUFF          = 0x1000   #< Use external Huffman table (for MJPEG).
        CODEC_FLAG_GRAY                 = 0x2000   #< Only decode/encode grayscale.
        CODEC_FLAG_EMU_EDGE             = 0x4000   #< Don't draw edges.
        CODEC_FLAG_PSNR                 = 0x8000   #< error[?] variables will be set during encoding.
        CODEC_FLAG_TRUNCATED            = 0x00010000 #< Input bitstream might be truncated at a random location instead of only at frame boundaries.
        CODEC_FLAG_NORMALIZE_AQP        = 0x00020000 #< Normalize adaptive quantization.
        CODEC_FLAG_INTERLACED_DCT       = 0x00040000 #< Use interlaced DCT.
        CODEC_FLAG_LOW_DELAY            = 0x00080000 #< Force low delay.
        CODEC_FLAG_ALT_SCAN             = 0x00100000 #< Use alternate scan.
        CODEC_FLAG_GLOBAL_HEADER        = 0x00400000 #< Place global headers in extradata instead of every keyframe.
        CODEC_FLAG_BITEXACT             = 0x00800000 #< Use only bitexact stuff (except (I)DCT).
        # Fx : Flag for h263+ extra options 
        CODEC_FLAG_AC_PRED              = 0x01000000 #< H.263 advanced intra coding / MPEG-4 AC prediction
        CODEC_FLAG_H263P_UMV            = 0x02000000 #< unlimited motion vector
        CODEC_FLAG_CBP_RD               = 0x04000000 #< Use rate distortion optimization for cbp.
        CODEC_FLAG_QP_RD                = 0x08000000 #< Use rate distortion optimization for qp selectioon.
        CODEC_FLAG_H263P_AIV            = 0x00000008 #< H.263 alternative inter VLC
        CODEC_FLAG_OBMC                 = 0x00000001 #< OBMC
        CODEC_FLAG_LOOP_FILTER          = 0x00000800 #< loop filter
        CODEC_FLAG_H263P_SLICE_STRUCT   = 0x10000000
        CODEC_FLAG_INTERLACED_ME        = 0x20000000 #< interlaced motion estimation
        CODEC_FLAG_SVCD_SCAN_OFFSET     = 0x40000000 #< Will reserve space for SVCD scan offset user data.
        CODEC_FLAG_CLOSED_GOP           = 0x80000000
        CODEC_FLAG2_FAST                = 0x00000001 #< Allow non spec compliant speedup tricks.
        CODEC_FLAG2_STRICT_GOP          = 0x00000002 #< Strictly enforce GOP size.
        CODEC_FLAG2_NO_OUTPUT           = 0x00000004 #< Skip bitstream encoding.
        CODEC_FLAG2_LOCAL_HEADER        = 0x00000008 #< Place global headers at every keyframe instead of in extradata.
        CODEC_FLAG2_BPYRAMID            = 0x00000010 #< H.264 allow B-frames to be used as references.
        CODEC_FLAG2_WPRED               = 0x00000020 #< H.264 weighted biprediction for B-frames
        CODEC_FLAG2_MIXED_REFS          = 0x00000040 #< H.264 one reference per partition, as opposed to one reference per macroblock
        CODEC_FLAG2_8X8DCT              = 0x00000080 #< H.264 high profile 8x8 transform
        CODEC_FLAG2_FASTPSKIP           = 0x00000100 #< H.264 fast pskip
        CODEC_FLAG2_AUD                 = 0x00000200 #< H.264 access unit delimiters
        CODEC_FLAG2_BRDO                = 0x00000400 #< B-frame rate-distortion optimization
        CODEC_FLAG2_INTRA_VLC           = 0x00000800 #< Use MPEG-2 intra VLC table.
        CODEC_FLAG2_MEMC_ONLY           = 0x00001000 #< Only do ME/MC (I frames -> ref, P frame -> ME+MC).
        CODEC_FLAG2_DROP_FRAME_TIMECODE = 0x00002000 #< timecode is in drop frame format.
        CODEC_FLAG2_SKIP_RD             = 0x00004000 #< RD optimal MB level residual skipping
        CODEC_FLAG2_CHUNKS              = 0x00008000 #< Input bitstream might be truncated at a packet boundaries instead of only at frame boundaries.
        CODEC_FLAG2_NON_LINEAR_QUANT    = 0x00010000 #< Use MPEG-2 nonlinear quantizer.
        CODEC_FLAG2_BIT_RESERVOIR       = 0x00020000 #< Use a bit reservoir when encoding if possible
        CODEC_FLAG2_MBTREE              = 0x00040000 #< Use macroblock tree ratecontrol (x264 only)
        CODEC_FLAG2_PSY                 = 0x00080000 #< Use psycho visual optimizations.
        CODEC_FLAG2_SSIM                = 0x00100000 #< Compute SSIM during encoding, error[] values are undefined.
        CODEC_FLAG2_INTRA_REFRESH       = 0x00200000 #< Use periodic insertion of intra blocks instead of keyframes.

        # codec capabilities
        CODEC_CAP_DRAW_HORIZ_BAND       = 0x0001 #< Decoder can use draw_horiz_band callback.
        CODEC_CAP_DR1                   = 0x0002 
        CODEC_CAP_PARSE_ONLY            = 0x0004
        CODEC_CAP_TRUNCATED             = 0x0008
        CODEC_CAP_HWACCEL               = 0x0010
        CODEC_CAP_DELAY                 = 0x0020
        CODEC_CAP_SMALL_LAST_FRAME      = 0x0040
        CODEC_CAP_HWACCEL_VDPAU         = 0x0080
        CODEC_CAP_SUBFRAMES             = 0x0100
        CODEC_CAP_EXPERIMENTAL          = 0x0200
        CODEC_CAP_CHANNEL_CONF          = 0x0400
        CODEC_CAP_NEG_LINESIZES         = 0x0800
        CODEC_CAP_FRAME_THREADS         = 0x1000

        # AVFrame pict_type values
        FF_I_TYPE            = 1         #< Intra
        FF_P_TYPE            = 2         #< Predicted
        FF_B_TYPE            = 3         #< Bi-dir predicted
        FF_S_TYPE            = 4         #< S(GMC)-VOP MPEG4
        FF_SI_TYPE           = 5         #< Switching Intra
        FF_SP_TYPE           = 6         #< Switching Predicte
        FF_BI_TYPE           = 7

        # AVFrame mb_type values
        #The following defines may change, don't expect compatibility if you use them.
        #Note bits 24-31 are reserved for codec specific use (h264 ref0, mpeg1 0mv, ...)
        MB_TYPE_INTRA4x4   = 0x0001
        MB_TYPE_INTRA16x16 = 0x0002 #FIXME H.264-specific
        MB_TYPE_INTRA_PCM  = 0x0004 #FIXME H.264-specific
        MB_TYPE_16x16      = 0x0008
        MB_TYPE_16x8       = 0x0010
        MB_TYPE_8x16       = 0x0020
        MB_TYPE_8x8        = 0x0040
        MB_TYPE_INTERLACED = 0x0080
        MB_TYPE_DIRECT2    = 0x0100 #FIXME
        MB_TYPE_ACPRED     = 0x0200
        MB_TYPE_GMC        = 0x0400
        MB_TYPE_SKIP       = 0x0800
        MB_TYPE_P0L0       = 0x1000
        MB_TYPE_P1L0       = 0x2000
        MB_TYPE_P0L1       = 0x4000
        MB_TYPE_P1L1       = 0x8000
        MB_TYPE_L0         = (MB_TYPE_P0L0 | MB_TYPE_P1L0)
        MB_TYPE_L1         = (MB_TYPE_P0L1 | MB_TYPE_P1L1)
        MB_TYPE_L0L1       = (MB_TYPE_L0   | MB_TYPE_L1)
        MB_TYPE_QUANT      = 0x00010000
        MB_TYPE_CBP        = 0x00020000
        
        # AVCodecContext error_concealment values
        FF_EC_GUESS_MV       = 1
        FF_EC_DEBLOCK        = 2
        
        # AVCodecContext debug values
        FF_DEBUG_PICT_INFO   = 1
        FF_DEBUG_RC          = 2
        FF_DEBUG_BITSTREAM   = 4
        FF_DEBUG_MB_TYPE     = 8
        FF_DEBUG_QP          = 16
        FF_DEBUG_MV          = 32
        FF_DEBUG_DCT_COEFF   = 0x00000040
        FF_DEBUG_SKIP        = 0x00000080
        FF_DEBUG_STARTCODE   = 0x00000100
        FF_DEBUG_PTS         = 0x00000200
        FF_DEBUG_ER          = 0x00000400
        FF_DEBUG_MMCO        = 0x00000800
        FF_DEBUG_BUGS        = 0x00001000
        FF_DEBUG_VIS_QP      = 0x00002000
        FF_DEBUG_VIS_MB_TYPE = 0x00004000
        FF_DEBUG_BUFFERS     = 0x00008000
        
        # AVCodecContext debug_mv values
        FF_DEBUG_VIS_MV_P_FOR  = 0x00000001 #< visualize forward predicted MVs of P frames
        FF_DEBUG_VIS_MV_B_FOR  = 0x00000002 #< visualize forward predicted MVs of B frames
        FF_DEBUG_VIS_MV_B_BACK = 0x00000004 #< visualize backward predicted MVs of B frames
        
        # AVCodecContex dtg_active_format values
        FF_DTG_AFD_SAME        = 8
        FF_DTG_AFD_4_3         = 9        #< 4:3
        FF_DTG_AFD_16_9        = 10       #< 16:9
        FF_DTG_AFD_14_9        = 11       #< 14:9
        FF_DTG_AFD_4_3_SP_14_9 = 13 
        FF_DTG_AFD_16_9_SP_14_9= 14
        FF_DTG_AFD_SP_4_3      = 15

        # AVCodecContex profile values
        FF_PROFILE_UNKNOWN     = -99
    
        FF_PROFILE_AAC_MAIN    = 0
        FF_PROFILE_AAC_LOW     = 1
        FF_PROFILE_AAC_SSR     = 2
        FF_PROFILE_AAC_LTP     = 3

        FF_PROFILE_H264_BASELINE  = 66
        FF_PROFILE_H264_MAIN      = 77
        FF_PROFILE_H264_EXTENDED  = 88
        FF_PROFILE_H264_HIGH      = 100
        FF_PROFILE_H264_HIGH_10   = 110
        FF_PROFILE_H264_HIGH_422  = 122
        FF_PROFILE_H264_HIGH_444  = 244
        FF_PROFILE_H264_CAVLC_444 = 44
        
        FF_LEVEL_UNKNOWN       = -99
        
        
    # ok libavcodec   52.113. 2    
    enum AVDiscard:
        # we leave some space between them for extensions (drop some keyframes for intra only or drop just some bidir frames)
        AVDISCARD_NONE   = -16 # discard nothing
        AVDISCARD_DEFAULT=   0 # discard useless packets like 0 size packets in avi
        AVDISCARD_NONREF =   8 # discard all non reference
        AVDISCARD_BIDIR  =  16 # discard all bidirectional frames
        AVDISCARD_NONKEY =  32 # discard all frames except keyframes
        AVDISCARD_ALL    =  48 # discard all

    # ok libavcodec   52.113. 2
    enum AVColorPrimaries:
        AVCOL_PRI_BT709       = 1    #< also ITU-R BT1361 / IEC 61966-2-4 / SMPTE RP177 Annex B
        AVCOL_PRI_UNSPECIFIED = 2
        AVCOL_PRI_BT470M      = 4
        AVCOL_PRI_BT470BG     = 5    #< also ITU-R BT601-6 625 / ITU-R BT1358 625 / ITU-R BT1700 625 PAL & SECAM
        AVCOL_PRI_SMPTE170M   = 6    #< also ITU-R BT601-6 525 / ITU-R BT1358 525 / ITU-R BT1700 NTSC
        AVCOL_PRI_SMPTE240M   = 7    #< functionally identical to above
        AVCOL_PRI_FILM        = 8
        AVCOL_PRI_NB          = 9    #< Not part of ABI
      
      
    # ok libavcodec   52.113. 2       
    enum AVColorTransferCharacteristic:
        AVCOL_TRC_BT709       = 1    #< also ITU-R BT1361
        AVCOL_TRC_UNSPECIFIED = 2
        AVCOL_TRC_GAMMA22     = 4    #< also ITU-R BT470M / ITU-R BT1700 625 PAL & SECAM
        AVCOL_TRC_GAMMA28     = 5    #< also ITU-R BT470BG
        AVCOL_TRC_NB          = 6    #< Not part of ABI


    # ok libavcodec   52.113. 2
    enum AVColorSpace:
        AVCOL_SPC_RGB         = 0
        AVCOL_SPC_BT709       = 1    #< also ITU-R BT1361 / IEC 61966-2-4 xvYCC709 / SMPTE RP177 Annex B
        AVCOL_SPC_UNSPECIFIED = 2
        AVCOL_SPC_FCC         = 4
        AVCOL_SPC_BT470BG     = 5    #< also ITU-R BT601-6 625 / ITU-R BT1358 625 / ITU-R BT1700 625 PAL & SECAM / IEC 61966-2-4 xvYCC601
        AVCOL_SPC_SMPTE170M   = 6    #< also ITU-R BT601-6 525 / ITU-R BT1358 525 / ITU-R BT1700 NTSC / functionally identical to above
        AVCOL_SPC_SMPTE240M   = 7
        AVCOL_SPC_NB          = 8    #< Not part of ABI


    # ok libavcodec   52.113. 2
    enum AVColorRange:
        AVCOL_RANGE_UNSPECIFIED = 0
        AVCOL_RANGE_MPEG        = 1  #< the normal 219*2^(n-8) "MPEG" YUV ranges
        AVCOL_RANGE_JPEG        = 2  #< the normal     2^n-1   "JPEG" YUV ranges
        AVCOL_RANGE_NB          = 3  #< Not part of ABI


    # ok libavcodec   52.113. 2
    enum AVChromaLocation:
        AVCHROMA_LOC_UNSPECIFIED = 0
        AVCHROMA_LOC_LEFT        = 1    #< mpeg2/4, h264 default
        AVCHROMA_LOC_CENTER      = 2    #< mpeg1, jpeg, h263
        AVCHROMA_LOC_TOPLEFT     = 3    #< DV
        AVCHROMA_LOC_TOP         = 4
        AVCHROMA_LOC_BOTTOMLEFT  = 5
        AVCHROMA_LOC_BOTTOM      = 6
        AVCHROMA_LOC_NB          = 7    #< Not part of ABI


    # ok libavcodec   52.113. 2
    enum CodecID:
        CODEC_ID_NONE,
    
        # video codecs 
        CODEC_ID_MPEG1VIDEO,
        CODEC_ID_MPEG2VIDEO, #< preferred ID for MPEG-1/2 video decoding
        CODEC_ID_MPEG2VIDEO_XVMC,
        CODEC_ID_H261,
        CODEC_ID_H263,
        CODEC_ID_RV10,
        CODEC_ID_RV20,
        CODEC_ID_MJPEG,
        CODEC_ID_MJPEGB,
        CODEC_ID_LJPEG,
        CODEC_ID_SP5X,
        CODEC_ID_JPEGLS,
        CODEC_ID_MPEG4,
        CODEC_ID_RAWVIDEO,
        CODEC_ID_MSMPEG4V1,
        CODEC_ID_MSMPEG4V2,
        CODEC_ID_MSMPEG4V3,
        CODEC_ID_WMV1,
        CODEC_ID_WMV2,
        CODEC_ID_H263P,
        CODEC_ID_H263I,
        CODEC_ID_FLV1,
        CODEC_ID_SVQ1,
        CODEC_ID_SVQ3,
        CODEC_ID_DVVIDEO,
        CODEC_ID_HUFFYUV,
        CODEC_ID_CYUV,
        CODEC_ID_H264,
        CODEC_ID_INDEO3,
        CODEC_ID_VP3,
        CODEC_ID_THEORA,
        CODEC_ID_ASV1,
        CODEC_ID_ASV2,
        CODEC_ID_FFV1,
        CODEC_ID_4XM,
        CODEC_ID_VCR1,
        CODEC_ID_CLJR,
        CODEC_ID_MDEC,
        CODEC_ID_ROQ,
        CODEC_ID_INTERPLAY_VIDEO,
        CODEC_ID_XAN_WC3,
        CODEC_ID_XAN_WC4,
        CODEC_ID_RPZA,
        CODEC_ID_CINEPAK,
        CODEC_ID_WS_VQA,
        CODEC_ID_MSRLE,
        CODEC_ID_MSVIDEO1,
        CODEC_ID_IDCIN,
        CODEC_ID_8BPS,
        CODEC_ID_SMC,
        CODEC_ID_FLIC,
        CODEC_ID_TRUEMOTION1,
        CODEC_ID_VMDVIDEO,
        CODEC_ID_MSZH,
        CODEC_ID_ZLIB,
        CODEC_ID_QTRLE,
        CODEC_ID_SNOW,
        CODEC_ID_TSCC,
        CODEC_ID_ULTI,
        CODEC_ID_QDRAW,
        CODEC_ID_VIXL,
        CODEC_ID_QPEG,
        CODEC_ID_XVID,        #< LIBAVCODEC_VERSION_MAJOR < 53
        CODEC_ID_PNG,
        CODEC_ID_PPM,
        CODEC_ID_PBM,
        CODEC_ID_PGM,
        CODEC_ID_PGMYUV,
        CODEC_ID_PAM,
        CODEC_ID_FFVHUFF,
        CODEC_ID_RV30,
        CODEC_ID_RV40,
        CODEC_ID_VC1,
        CODEC_ID_WMV3,
        CODEC_ID_LOCO,
        CODEC_ID_WNV1,
        CODEC_ID_AASC,
        CODEC_ID_INDEO2,
        CODEC_ID_FRAPS,
        CODEC_ID_TRUEMOTION2,
        CODEC_ID_BMP,
        CODEC_ID_CSCD,
        CODEC_ID_MMVIDEO,
        CODEC_ID_ZMBV,
        CODEC_ID_AVS,
        CODEC_ID_SMACKVIDEO,
        CODEC_ID_NUV,
        CODEC_ID_KMVC,
        CODEC_ID_FLASHSV,
        CODEC_ID_CAVS,
        CODEC_ID_JPEG2000,
        CODEC_ID_VMNC,
        CODEC_ID_VP5,
        CODEC_ID_VP6,
        CODEC_ID_VP6F,
        CODEC_ID_TARGA,
        CODEC_ID_DSICINVIDEO,
        CODEC_ID_TIERTEXSEQVIDEO,
        CODEC_ID_TIFF,
        CODEC_ID_GIF,
        CODEC_ID_FFH264,
        CODEC_ID_DXA,
        CODEC_ID_DNXHD,
        CODEC_ID_THP,
        CODEC_ID_SGI,
        CODEC_ID_C93,
        CODEC_ID_BETHSOFTVID,
        CODEC_ID_PTX,
        CODEC_ID_TXD,
        CODEC_ID_VP6A,
        CODEC_ID_AMV,
        CODEC_ID_VB,
        CODEC_ID_PCX,
        CODEC_ID_SUNRAST,
        CODEC_ID_INDEO4,
        CODEC_ID_INDEO5,
        CODEC_ID_MIMIC,
        CODEC_ID_RL2,
        CODEC_ID_8SVX_EXP,
        CODEC_ID_8SVX_FIB,
        CODEC_ID_ESCAPE124,
        CODEC_ID_DIRAC,
        CODEC_ID_BFI,
        CODEC_ID_CMV,
        CODEC_ID_MOTIONPIXELS,
        CODEC_ID_TGV,
        CODEC_ID_TGQ,
        CODEC_ID_TQI,
        CODEC_ID_AURA,
        CODEC_ID_AURA2,
        CODEC_ID_V210X,
        CODEC_ID_TMV,
        CODEC_ID_V210,
        CODEC_ID_DPX,
        CODEC_ID_MAD,
        CODEC_ID_FRWU,
        CODEC_ID_FLASHSV2,
        CODEC_ID_CDGRAPHICS,
        CODEC_ID_R210,
        CODEC_ID_ANM,
        CODEC_ID_BINKVIDEO,
        CODEC_ID_IFF_ILBM,
        CODEC_ID_IFF_BYTERUN1,
        CODEC_ID_KGV1,
        CODEC_ID_YOP,
        CODEC_ID_VP8,
        CODEC_ID_PICTOR,
        CODEC_ID_ANSI,
        CODEC_ID_A64_MULTI,
        CODEC_ID_A64_MULTI5,
        CODEC_ID_R10K,
        CODEC_ID_MXPEG,
        CODEC_ID_LAGARITH,
        CODEC_ID_PRORES,
        
        # various PCM "codecs" 
        CODEC_ID_PCM_S16LE= 0x10000,
        CODEC_ID_PCM_S16BE,
        CODEC_ID_PCM_U16LE,
        CODEC_ID_PCM_U16BE,
        CODEC_ID_PCM_S8,
        CODEC_ID_PCM_U8,
        CODEC_ID_PCM_MULAW,
        CODEC_ID_PCM_ALAW,
        CODEC_ID_PCM_S32LE,
        CODEC_ID_PCM_S32BE,
        CODEC_ID_PCM_U32LE,
        CODEC_ID_PCM_U32BE,
        CODEC_ID_PCM_S24LE,
        CODEC_ID_PCM_S24BE,
        CODEC_ID_PCM_U24LE,
        CODEC_ID_PCM_U24BE,
        CODEC_ID_PCM_S24DAUD,
        CODEC_ID_PCM_ZORK,
        CODEC_ID_PCM_S16LE_PLANAR,
        CODEC_ID_PCM_DVD,
        CODEC_ID_PCM_F32BE,
        CODEC_ID_PCM_F32LE,
        CODEC_ID_PCM_F64BE,
        CODEC_ID_PCM_F64LE,
        CODEC_ID_PCM_BLURAY,
        CODEC_ID_PCM_LXF,
       
         # various ADPCM codecs 
        CODEC_ID_ADPCM_IMA_QT= 0x11000,
        CODEC_ID_ADPCM_IMA_WAV,
        CODEC_ID_ADPCM_IMA_DK3,
        CODEC_ID_ADPCM_IMA_DK4,
        CODEC_ID_ADPCM_IMA_WS,
        CODEC_ID_ADPCM_IMA_SMJPEG,
        CODEC_ID_ADPCM_MS,
        CODEC_ID_ADPCM_4XM,
        CODEC_ID_ADPCM_XA,
        CODEC_ID_ADPCM_ADX,
        CODEC_ID_ADPCM_EA,
        CODEC_ID_ADPCM_G726,
        CODEC_ID_ADPCM_CT,
        CODEC_ID_ADPCM_SWF,
        CODEC_ID_ADPCM_YAMAHA,
        CODEC_ID_ADPCM_SBPRO_4,
        CODEC_ID_ADPCM_SBPRO_3,
        CODEC_ID_ADPCM_SBPRO_2,
        CODEC_ID_ADPCM_THP,
        CODEC_ID_ADPCM_IMA_AMV,
        CODEC_ID_ADPCM_EA_R1,
        CODEC_ID_ADPCM_EA_R3,
        CODEC_ID_ADPCM_EA_R2,
        CODEC_ID_ADPCM_IMA_EA_SEAD,
        CODEC_ID_ADPCM_IMA_EA_EACS,
        CODEC_ID_ADPCM_EA_XAS,
        CODEC_ID_ADPCM_EA_MAXIS_XA,
        CODEC_ID_ADPCM_IMA_ISS,
        CODEC_ID_ADPCM_G722,
    
        # AMR 
        CODEC_ID_AMR_NB= 0x12000,
        CODEC_ID_AMR_WB,
     
        # RealAudio codecs
        CODEC_ID_RA_144= 0x13000,
        CODEC_ID_RA_288,
    
        # various DPCM codecs 
        CODEC_ID_ROQ_DPCM= 0x14000,
        CODEC_ID_INTERPLAY_DPCM,
        CODEC_ID_XAN_DPCM,
        CODEC_ID_SOL_DPCM,
    
        # audio codecs 
        CODEC_ID_MP2= 0x15000,
        CODEC_ID_MP3, #< preferred ID for decoding MPEG audio layer 1, 2 or 3
        CODEC_ID_AAC,
        CODEC_ID_AC3,
        CODEC_ID_DTS,
        CODEC_ID_VORBIS,
        CODEC_ID_DVAUDIO,
        CODEC_ID_WMAV1,
        CODEC_ID_WMAV2,
        CODEC_ID_MACE3,
        CODEC_ID_MACE6,
        CODEC_ID_VMDAUDIO,
        CODEC_ID_SONIC,
        CODEC_ID_SONIC_LS,
        CODEC_ID_FLAC,
        CODEC_ID_MP3ADU,
        CODEC_ID_MP3ON4,
        CODEC_ID_SHORTEN,
        CODEC_ID_ALAC,
        CODEC_ID_WESTWOOD_SND1,
        CODEC_ID_GSM, #< as in Berlin toast format
        CODEC_ID_QDM2,
        CODEC_ID_COOK,
        CODEC_ID_TRUESPEECH,
        CODEC_ID_TTA,
        CODEC_ID_SMACKAUDIO,
        CODEC_ID_QCELP,
        CODEC_ID_WAVPACK,
        CODEC_ID_DSICINAUDIO,
        CODEC_ID_IMC,
        CODEC_ID_MUSEPACK7,
        CODEC_ID_MLP,
        CODEC_ID_GSM_MS, # as found in WAV 
        CODEC_ID_ATRAC3,
        CODEC_ID_VOXWARE,
        CODEC_ID_APE,
        CODEC_ID_NELLYMOSER,
        CODEC_ID_MUSEPACK8,
        CODEC_ID_SPEEX,
        CODEC_ID_WMAVOICE,
        CODEC_ID_WMAPRO,
        CODEC_ID_WMALOSSLESS,
        CODEC_ID_ATRAC3P,
        CODEC_ID_EAC3,
        CODEC_ID_SIPR,
        CODEC_ID_MP1,
        CODEC_ID_TWINVQ,
        CODEC_ID_TRUEHD,
        CODEC_ID_MP4ALS,
        CODEC_ID_ATRAC1,
        CODEC_ID_BINKAUDIO_RDFT,
        CODEC_ID_BINKAUDIO_DCT,
        CODEC_ID_AAC_LATM,
        CODEC_ID_QDMC,
        
        # subtitle codecs
        CODEC_ID_DVD_SUBTITLE= 0x17000,
        CODEC_ID_DVB_SUBTITLE,
        CODEC_ID_TEXT,  #< raw UTF-8 text
        CODEC_ID_XSUB,
        CODEC_ID_SSA,
        CODEC_ID_MOV_TEXT,
        CODEC_ID_HDMV_PGS_SUBTITLE,
        CODEC_ID_DVB_TELETEXT,
        CODEC_ID_SRT,
    
        CODEC_ID_TTF= 0x18000,
        CODEC_ID_PROBE= 0x19000,
        CODEC_ID_MPEG2TS= 0x20000
        CODEC_ID_FFMETADATA=0x21000,   #< Dummy codec for streams containing only metadata information.
   

    # ok libavcodec   52.113. 2    
    enum CodecType:
        CODEC_TYPE_UNKNOWN     = AVMEDIA_TYPE_UNKNOWN
        CODEC_TYPE_VIDEO       = AVMEDIA_TYPE_VIDEO
        CODEC_TYPE_AUDIO       = AVMEDIA_TYPE_AUDIO
        CODEC_TYPE_DATA        = AVMEDIA_TYPE_DATA
        CODEC_TYPE_SUBTITLE    = AVMEDIA_TYPE_SUBTITLE
        CODEC_TYPE_ATTACHMENT  = AVMEDIA_TYPE_ATTACHMENT
        CODEC_TYPE_NB          = AVMEDIA_TYPE_NB


    # ok libavcodec   52.113. 2
    struct AVPanScan:
        int id
        int width
        int height
        int16_t position[3][2]

  
  # ok libavcodec   52.113. 2
    struct AVPacket:
        int64_t pts            #< presentation time stamp in time_base units
        int64_t dts            #< decompression time stamp in time_base units
        char *data
        int   size
        int   stream_index
        int   flags
        int   duration         #< presentation duration in time_base units (0 if not available)
        void  *destruct
        void  *priv
        int64_t pos            #< byte position in Track, -1 if unknown
        #===============================================================================
        # * Time difference in AVStream->time_base units from the pts of this
        # * packet to the point at which the output from the decoder has converged
        # * independent from the availability of previous frames. That is, the
        # * frames are virtually identical no matter if decoding started from
        # * the very first frame or from this keyframe.
        # * Is AV_NOPTS_VALUE if unknown.
        # * This field is not the display duration of the current packet.
        # * This field has no meaning if the packet does not have AV_PKT_FLAG_KEY
        # * set.
        # *
        # * The purpose of this field is to allow seeking in streams that have no
        # * keyframes in the conventional sense. It corresponds to the
        # * recovery point SEI in H.264 and match_time_delta in NUT. It is also
        # * essential for some types of subtitle streams to ensure that all
        # * subtitles are correctly displayed after seeking.
        #===============================================================================
        int64_t convergence_duration
  
    # ok libavcodec   52.113. 2
    struct AVProfile:
        int         profile
        char *      name                    #< short name for the profile


    # ok libavcodec   52.113. 2
    struct AVCodec:
        char *        name
        AVMediaType   type
        CodecID       id
        int           priv_data_size
        int  *        init                   # function pointer
        int  *        encode                 # function pointer
        int  *        close                  # function pointer
        int  *        decode                 # function pointer
        int           capabilities           #< see CODEC_CAP_xxx in 
        AVCodec *     next
        void *        flush        
        AVRational *  supported_framerates   #< array of supported framerates, or NULL 
                                             #  if any, array is terminated by {0,0}
        PixelFormat * pix_fmts               #< array of supported pixel formats, or NULL 
                                             #  if unknown, array is terminanted by -1
        char *        long_name    
        int  *        supported_samplerates  #< array of supported audio samplerates, or NULL if unknown, array is terminated by 0
        AVSampleFormat * sample_fmts         #< array of supported sample formats, or NULL if unknown, array is terminated by -1
        int64_t *     channel_layouts        #< array of support channel layouts, or NULL if unknown. array is terminated by 0
        uint8_t       max_lowres             #< maximum value for lowres supported by the decoder
        void *        priv_class             #< AVClass for the private context
        AVProfile *   profiles               #< array of recognized profiles, or NULL if unknown, array is terminated by {FF_PROFILE_UNKNOWN}
        int  *        init_thread_copy       # function pointer
        int  *        update_thread_context  # function pointer


    # ok libavcodec   52.113. 2
    struct AVFrame:
        uint8_t *data[4]                        #< pointer to the picture planes
        int linesize[4]                      #<
        uint8_t *base[4]                     #< pointer to the first allocated byte of the picture. Can be used in get_buffer/release_buffer
        int key_frame                        #< 1 -> keyframe, 0-> not
        int pict_type                        #< Picture type of the frame, see ?_TYPE below
        int64_t pts                          #< presentation timestamp in time_base units (time when frame should be shown to user)
        int coded_picture_number             #< picture number in bitstream order
        int display_picture_number           #< picture number in display order
        int quality                          #< quality (between 1 (good) and FF_LAMBDA_MAX (bad))
        int age                              #< buffer age (1->was last buffer and dint change, 2->..., ...)
        int reference                        #< is this picture used as reference
        int qscale_table                     #< QP table
        int qstride                          #< QP store stride
        uint8_t *mbskip_table                #< mbskip_table[mb]>=1 if MB didn't change, stride= mb_width = (width+15)>>4
        int16_t (*motion_val[2])[2]          #< motion vector table
        uint32_t *mb_type                    #< macroblock type table: mb_type_base + mb_width + 2
        uint8_t motion_subsample_log2        #< log2 of the size of the block which a single vector in motion_val represents: (4->16x16, 3->8x8, 2-> 4x4, 1-> 2x2)
        void *opaque                         #< for some private data of the user
        uint64_t error[4]                    #< unused for decodig
        int type                             #< type of the buffer (to keep track of who has to deallocate data[*]
        int repeat_pict                      #<  When decoding, this signals how much the picture must be delayed: extra_delay = repeat_pict / (2*fps)
        int qscale_type
        int interlaced_frame                 #< The content of the picture is interlaced
        int top_field_first                  #< If the content is interlaced, is top field displayed first
        AVPanScan *pan_scan                  #< Pan scan
        int palette_has_changed              #< Tell user application that palette has changed from previous frame
        int buffer_hints                     #< 
        short *dct_coeff                     #< DCT coefficients
        int8_t *ref_index[2]                 #< motion reference frame index, the order in which these are stored can depend on the codec
        # reordered opaque 64bit (generally an integer or a double precision float
        # PTS but can be anything). 
        # The user sets AVCodecContext.reordered_opaque to represent the input at
        # that time, the decoder reorders values as needed and sets AVFrame.reordered_opaque
        # to exactly one of the values provided by the user through AVCodecContext.reordered_opaque
        # @deprecated in favor of pkt_pts        
        int64_t reordered_opaque
        void *hwaccel_picture_private        #< hardware accelerator private data
        int64_t pkt_pts                      #< reordered pts from the last AVPacket that has been input into the decoder
        int64_t pkt_dts                      #< dts from the last AVPacket that has been input into the decoder
#        AVCodecContext *owner                #< the AVCodecContext which ff_thread_get_buffer() was last called on
        void *thread_opaque                  #< used by multithreading to store frame-specific info


    # ok libavcodec   52.113. 2
    struct AVCodecContext:
        void *      av_class
        int         bit_rate
        int         bit_rate_tolerance
        int         flags
        int         sub_id
        int         me_method
        uint8_t *   extradata
        int         extradata_size
        AVRational  time_base
        int         width
        int         height
        int         gop_size
        PixelFormat pix_fmt
        int         rate_emu
        void *      draw_horiz_band
        int         sample_rate
        int         channels
        int         sample_fmt
        int         frame_size
        int         frame_number
        int         real_pict_num          #< only for LIBAVCODEC_VERSION_MAJOR < 53
        int         delay
        float       qcompress
        float       qblur
        int         qmin
        int         qmax
        int         max_qdiff
        int         max_b_frames
        float       b_quant_factor
        int         rc_strategy            #< will be removed in later libav versions
        int         b_frame_strategy
        int         hurry_up               #< hurry up amount: decoding: Set by user. 1-> Skip B-frames, 2-> Skip IDCT/dequant too, 5-> Skip everything except header
        AVCodec *   codec
        void *      priv_data
        int         rtp_payload_size
        void *      rtp_callback
        # statistics, used for 2-pass encoding
        int         mv_bits
        int         header_bits
        int         i_tex_bits
        int         p_tex_bits
        int         i_count
        int         p_count
        int         skip_count
        int         misc_bits
        int         frame_bits
        void *      opaque
        char        codec_name[32]
        int         codec_type             #< see AVMEDIA_TYPE_xxx in avcodec.h
        CodecID     codec_id               #< see CODEC_ID_xxx in avcodec.h
        unsigned int codec_tag
        int         workaround_bugs
        int         luma_elim_threshold
        int         chroma_elim_threshold
        int         strict_std_compliance  #< see FF_COMPLIANCE_xxx in avcodec.h
        float       b_quant_offset
        int         error_recognition      #< see FF_ER_xxx in avcodec.h
        int  *      get_buffer
        void *      release_buffer
        int         has_b_frames           #< Size of the frame reordering buffer in the decoder: e.g. For MPEG-2 it is 1 IPB or 0 low delay IP 
        int         block_align
        int         parse_only             #< decoding only: If true, only parsing is done
                                           #(function avcodec_parse_frame()). The frame
                                           # data is returned. Only MPEG codecs support this now.
        int         mpeg_quant
        char *      stats_out
        char *      stats_in
        float       rc_qsquish
        float       rc_qmod_amp
        int         rc_qmod_freq
        void *      rc_override
        int         rc_override_count
        char *      rc_eq
        int         rc_max_rate
        int         rc_min_rate
        int         rc_buffer_size
        float       rc_buffer_aggressivity
        float       i_quant_factor
        float       i_quant_offset
        float       rc_initial_cplx
        int         dct_algo                #< only coding: DCT algorithm see FF_DCT_xxx in avcodec.h
        float       lumi_masking
        float       temporal_cplx_masking
        float       spatial_cplx_masking
        float       p_masking
        float       dark_masking
        int         idct_algo               #< IDCT algorithm: see  FF_IDCT_xxx in avcodec.h
        int         slice_count
        int *       slice_offset
        int         error_concealment       #< only decoding: see FF_EC_xxx in avcodec.h
        unsigned    dsp_mask           #< dsp_mask could be add used to disable unwanted CPU features (i.e. MMX, SSE. ...)
                                        # see FF_MM_xxx in avcodec.h
        int         bits_per_coded_sample
        int         prediction_method       #< only encoding
        AVRational  sample_aspect_ratio
        AVFrame *   coded_frame       #< the picture in the bitstream
        int         debug                   #< encoding/decoding: see FF_DEBUG_xxx in avcodec.h
        int         debug_mv
        uint64_t    error[4]
        int         mb_qmin
        int         mb_qmax
        int         me_cmp
        int         me_sub_cmp
        int         mb_cmp
        int         ildct_cmp
        int         dia_size
        int         last_predictor_count
        int         pre_me
        int         me_pre_cmp
        int         pre_dia_size
        int         me_subpel_quality
        PixelFormat * get_format
        int         dtg_active_format        #< decoding: DTG active format information 
                                             # (additional aspect ratio  information 
                                             # only used in DVB MPEG-2 transport streams)
                                             # 0  if not set. See FF_DTG_AFD_xxx in avcodec.h
        int         me_range
        int         intra_quant_bias
        int         inter_quant_bias
        int         color_table_id
        int         internal_buffer_count
        void *      internal_buffer
        int         global_quality
        int         coder_type
        int         context_model
        int         slice_flags                #< see SLICE_FLAG_xxx in avcodec.h
        int         xvmc_acceleration
        int         mb_decision
        uint16_t *  intra_matrix
        uint16_t *  inter_matrix
        unsigned int stream_codec_tag          #< decoding: fourcc from the AVI stream header (LSB first, so "ABCD" -> ('D'<<24) + ('C'<<16) + ('B'<<8) + 'A')
        int         scenechange_threshold      #< encoding
        int         lmin
        int         lmax
        void *      palctrl             #< LIBAVCODEC_VERSION_MAJOR < 54
        int         noise_reduction
        int  *      reget_buffer
        int         rc_initial_buffer_occupancy
        int         inter_threshold
        int         flags2                     #< see CODEC_FLAG2_xxx in avcodec.h
        int         error_rate                 #< EV
        int         antialias_algo             #< DA MP3 antialias algorithm, see FF_AA_* below
        int         quantizer_noise_shaping    #< E
        int         thread_count               #< E/D set the number of threads
        int  *      execute        
        void *      thread_opaque
        int         me_threshold
        int         mb_threshold
        int         intra_dc_precision
        int         nsse_weight
        int         skip_top
        int         skip_bottom
        int         profile                    #< profile, see FF_PROFILE_xxx in avcodec.h
        int         level                      #< level, see FF_LEVEL_xxx in avcodec.h
        int         lowres                     #< decoding: low resolution decoding,
                                               # 1-> 1/2 size, 2->1/4 size
        int         coded_width
        int         coded_height
        int         frame_skip_threshold
        int         frame_skip_factor
        int         frame_skip_exp
        int         frame_skip_cmp
        float       border_masking
        int         mb_lmin
        int         mb_lmax
        int         me_penalty_compensation
        AVDiscard   skip_loop_filter        #< VD
        AVDiscard   skip_idct               #< VD
        AVDiscard   skip_frame              #< VD
        int         bidir_refine            #< VE 
        int         brd_scale               #< VE 
        float       crf                     #< VE
        int         cqp                     #< VE
        int         keyint_min              #< VE: minimum GOP size
        int         refs                    #< VE: number of reference frames
        int         chromaoffset            #< VE: chroma qp offset from luma
        int         bframebias              #< VE: Influences how often B-frames are used
        int         trellis                 #< VE: trellis RD quantization
        float       complexityblur          #< VE: Reduce fluctuations in qp (before curve compression)
        int         deblockalpha            #< VE: in-loop deblocking filter alphac0 parameter (range: -6..6)
        int         deblockbeta             #< VE: in-loop deblocking filter beta parameter (range: -6..6)
        int         partitions              #< VE: macroblock subpartition sizes to consider 
                                            #      - p8x8, p4x4, b8x8, i8x8, i4x4, see X264_PART_xxx in avcodec.h
        int         directpred              #< VE: direct MV prediction mode - 0 (none), 1 (spatial), 2 (temporal), 3 (auto)
        int         cutoff                  #< AE: Audio cutoff bandwidth (0 means "automatic")
        int         scenechange_factor      #< VE: Multiplied by qscale for each frame and added to scene_change_score
        int         mv0_threshold           #< VE: Note: Value depends upon the compare function used for fullpel ME 
        int         b_sensitivity           #< VE: Adjusts sensitivity of b_frame_strategy 1 
        int         compression_level       #< VE
        int         use_lpc                 #< AE
        int         lpc_coeff_precision     #< AE
        int         min_prediction_order    #< AE
        int         max_prediction_order    #< AE
        int         prediction_order_method 
        int         min_partition_order
        int         max_partition_order
        int64_t     timecode_frame_start    #< VE: GOP timecode frame start number, in non drop frame format 
        int         request_channels        #< Decoder should decode to this many channels if it can (0 for default)
                                            # LIBAVCODEC_VERSION_MAJOR < 53
        float       drc_scale               #< AD: Percentage of dynamic range compression to be applied by the decoder
                                            # The default value is 1.0, corresponding to full compression.
        int64_t     reordered_opaque        #<  @deprecated in favor of pkt_pts, opaque 64bit number (generally a PTS) 
                                            # that will be reordered and output in 
                                            # AVFrame.reordered_opaque
        int         bits_per_raw_sample     #< VE/VD: Bits per sample/pixel of internal libavcodec pixel/sample format
        int64_t     channel_layout          #< AE/AD: Audio channel layout
        int64_t     request_channel_layout  #< AD: Request decoder to use this channel layout if it can (0 for default)
        float       rc_max_available_vbv_use #< Ratecontrol attempt to use, at maximum, <value> of what can be used without an underflow        
        float       rc_min_vbv_overflow_use #< Ratecontrol attempt to use, at least, <value> times the amount needed to prevent a vbv overflow
        void *      hwaccel                 #< Hardware accelerator in use
        int         ticks_per_frame         #< VD/VE: Set to time_base ticks per frame. Default 1, e.g., H.264/MPEG-2 set it to 2.
        void *      hwaccel_context         #< Hardware accelerator context
        AVColorPrimaries color_primaries    #< VE/VD: Chromaticity coordinates of the source primaries
        AVColorTransferCharacteristic color_trc #< VE/VD: Color Transfer Characteristic 
        AVColorSpace colorspace             #< VE/VD: YUV colorspace type
        AVColorRange color_range            #< VE/VD:  MPEG vs JPEG YUV range
        AVChromaLocation chroma_sample_location #< VE/VD: This defines the location of chroma samples
        int  *      execute2    
        int         weighted_p_pred         #< VE: explicit P-frame weighted prediction analysis method
        int         aq_mode
        float       aq_strength
        float       psy_rd                  #< VE
        float       psy_trellis             #< VE
        int         rc_lookahead             #< VE
        float       crf_max             #< VE
        int         log_level_offset
        int         lpc_type
        int         lpc_passes
        int         slices                        #< Number of slices
        uint8_t *   subtitle_header
        int         subtitle_header_size
        AVPacket *  pkt                     #< VD: Current packet as passed into the decoder
        int         is_copy                 #< VE/VD: Whether this is a copy of the context which had init() called on it, This is used by multithreading - shared tables and picture pointers should be freed from the original context only.
        int         thread_type             #< VES/VDS: Which multithreading methods to use: frame 1, slice 2
        int         active_thread_type      #< VEG/VDG: Which multithreading methods are in use by the codec
        int         thread_safe_callbacks   #< VES/VDS:  Set by the client if its custom get_buffer() callback can be called
        uint64_t    vbv_delay               #< VEG: VBV delay coded in the last frame (in periods of a 27 MHz clock)
    
    
    # ok libavcodec   52.113. 2  
    struct AVPicture:
        uint8_t *data[4]
        int linesize[4]


    # AVCodecParserContext.flags
    enum:
        PARSER_FLAG_COMPLETE_FRAMES          = 0x0001
        PARSER_FLAG_ONCE                     = 0x0002
        PARSER_FLAG_FETCHED_OFFSET           = 0x0004        #< Set if the parser has a valid file offset

    # for AVCodecParserContext array lengths
    enum:        
        AV_PARSER_PTS_NB = 4        
     

    struct AVCodecParser:
        pass
     
     
    struct AVCodecParserContext:
        void *priv_data
        AVCodecParser *parser
        int64_t frame_offset                #< offset of the current frame 
        int64_t cur_offset                      #< current offset (incremented by each av_parser_parse()) 
        int64_t next_frame_offset               #< offset of the next frame 
        # video info 
        int pict_type #< XXX: Put it back in AVCodecContext. 
        #     * This field is used for proper frame duration computation in lavf.
        #     * It signals, how much longer the frame duration of the current frame
        #     * is compared to normal frame duration.
        #     * frame_duration = (1 + repeat_pict) * time_base
        #     * It is used by codecs like H.264 to display telecined material.
        int repeat_pict #< XXX: Put it back in AVCodecContext. 
        int64_t pts     #< pts of the current frame 
        int64_t dts     #< dts of the current frame 

        # private data 
        int64_t last_pts
        int64_t last_dts
        int fetch_timestamp

        int cur_frame_start_index
        int64_t cur_frame_offset[AV_PARSER_PTS_NB]
        int64_t cur_frame_pts[AV_PARSER_PTS_NB]
        int64_t cur_frame_dts[AV_PARSER_PTS_NB]
        int flags
        int64_t offset      #< byte offset from starting packet start
        int64_t cur_frame_end[AV_PARSER_PTS_NB]
        #     * Set by parser to 1 for key frames and 0 for non-key frames.
        #     * It is initialized to -1, so if the parser doesn't set this flag,
        #     * old-style fallback using FF_I_TYPE picture type as key frames
        #     * will be used.
        int key_frame
        #     * Time difference in stream time base units from the pts of this
        #     * packet to the point at which the output from the decoder has converged
        #     * independent from the availability of previous frames. That is, the
        #     * frames are virtually identical no matter if decoding started from
        #     * the very first frame or from this keyframe.
        #     * Is AV_NOPTS_VALUE if unknown.
        #     * This field is not the display duration of the current frame.
        #     * This field has no meaning if the packet does not have AV_PKT_FLAG_KEY
        #     * set.
        #     *
        #     * The purpose of this field is to allow seeking in streams that have no
        #     * keyframes in the conventional sense. It corresponds to the
        #     * recovery point SEI in H.264 and match_time_delta in NUT. It is also
        #     * essential for some types of subtitle streams to ensure that all
        #     * subtitles are correctly displayed after seeking.
        int64_t convergence_duration
        # Timestamp generation support:
        #     * Synchronization point for start of timestamp generation.
        #     *
        #     * Set to >0 for sync point, 0 for no sync point and <0 for undefined
        #     * (default).
        #     *
        #     * For example, this corresponds to presence of H.264 buffering period
        #     * SEI message.
        int dts_sync_point
        #     * Offset of the current timestamp against last timestamp sync point in
        #     * units of AVCodecContext.time_base.
        #     * Set to INT_MIN when dts_sync_point unused. Otherwise, it must
        #     * contain a valid timestamp offset.
        #     * Note that the timestamp of sync point has usually a nonzero
        #     * dts_ref_dts_delta, which refers to the previous sync point. Offset of
        #     * the next frame after timestamp sync point will be usually 1.
        #     * For example, this corresponds to H.264 cpb_removal_delay.
        int dts_ref_dts_delta
        #     * Presentation delay of current frame in units of AVCodecContext.time_base.
        #     * Set to INT_MIN when dts_sync_point unused. Otherwise, it must
        #     * contain valid non-negative timestamp delta (presentation time of a frame
        #     * must not lie in the past).
        #     * This delay represents the difference between decoding and presentation
        #     * time of the frame.
        #     * For example, this corresponds to H.264 dpb_output_delay.
        int pts_dts_delta
        int64_t cur_frame_pos[AV_PARSER_PTS_NB]            #< Position of the packet in file. Analogous to cur_frame_pts/dts
        int64_t pos                                        #< * Byte position of currently parsed frame in stream.
        int64_t last_pos                                   #< * Previous frame byte position.
        

    AVCodec *avcodec_find_decoder(CodecID id)
    
    int avcodec_open(AVCodecContext *avctx, AVCodec *codec)

    int avcodec_close(AVCodecContext *avctx)

    # deprecated ... use instead avcodec_decode_video2
    #int avcodec_decode_video(AVCodecContext *avctx, AVFrame *picture,
    #                     int *got_picture_ptr,
    #                     char *buf, int buf_size)
    int avcodec_decode_video2(AVCodecContext *avctx, AVFrame *picture,
                         int *got_picture_ptr,
                         AVPacket *avpkt)
                         
    # TODO                     
    # deprecated ... use instead avcodec_decode_audio3
    #int avcodec_decode_audio2(AVCodecContext *avctx, #AVFrame *picture,
    #                     int16_t * samples, int * frames,
    #                     void *buf, int buf_size)
    int avcodec_decode_audio3(AVCodecContext *avctx, int16_t *samples,
                         int *frame_size_ptr,
                         AVPacket *avpkt)

    int avpicture_fill(AVPicture *picture, uint8_t *ptr,
                       PixelFormat pix_fmt, int width, int height)
    int avpicture_layout(AVPicture* src, PixelFormat pix_fmt, 
                         int width, int height, unsigned char *dest, int dest_size)

    int avpicture_get_size(PixelFormat pix_fmt, int width, int height)
    void avcodec_get_chroma_sub_sample(PixelFormat pix_fmt, int *h_shift, int *v_shift)
    char *avcodec_get_pix_fmt_name(PixelFormat pix_fmt)
    void avcodec_set_dimensions(AVCodecContext *s, int width, int height)

    AVFrame *avcodec_alloc_frame()
    
    void avcodec_flush_buffers(AVCodecContext *avctx)

    # Return a single letter to describe the given picture type pict_type.
    char av_get_pict_type_char(int pict_type)

    # * Parse a packet.
    # *
    # * @param s             parser context.
    # * @param avctx         codec context.
    # * @param poutbuf       set to pointer to parsed buffer or NULL if not yet finished.
    # * @param poutbuf_size  set to size of parsed buffer or zero if not yet finished.
    # * @param buf           input buffer.
    # * @param buf_size      input length, to signal EOF, this should be 0 (so that the last frame can be output).
    # * @param pts           input presentation timestamp.
    # * @param dts           input decoding timestamp.
    # * @param pos           input byte position in stream.
    # * @return the number of bytes of the input bitstream used.
    # *
    # * Example:
    # * @code
    # *   while(in_len){
    # *       len = av_parser_parse2(myparser, AVCodecContext, &data, &size,
    # *                                        in_data, in_len,
    # *                                        pts, dts, pos);
    # *       in_data += len;
    # *       in_len  -= len;
    # *
    # *       if(size)
    # *          decode_frame(data, size);
    # *   }
    # * @endcode
    int av_parser_parse2(AVCodecParserContext *s,
                     AVCodecContext *avctx,
                     uint8_t **poutbuf, int *poutbuf_size,
                     uint8_t *buf, int buf_size,
                     int64_t pts, int64_t dts,
                     int64_t pos)
    int av_parser_change(AVCodecParserContext *s,
                     AVCodecContext *avctx,
                     uint8_t **poutbuf, int *poutbuf_size,
                     uint8_t *buf, int buf_size, int keyframe)
    void av_parser_close(AVCodecParserContext *s)


    # * Free a packet.
    # * @param pkt packet to free
    void av_free_packet(AVPacket *pkt)


##################################################################################
# Used for debugging
##################################################################################

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


##################################################################################
# ok libavformat  52.102. 0
cdef extern from "libavformat/avformat.h":

    enum:    
        AVSEEK_FLAG_BACKWARD = 1 #< seek backward
        AVSEEK_FLAG_BYTE     = 2 #< seeking based on position in bytes
        AVSEEK_FLAG_ANY      = 4 #< seek to any frame, even non-keyframes
        AVSEEK_FLAG_FRAME    = 8 #< seeking based on frame number
    
    struct AVFrac:
        int64_t val, num, den

    struct AVProbeData:
        char *filename
        unsigned char *buf
        int buf_size

    struct AVCodecParserContext:
        pass

    struct AVIndexEntry:
        int64_t pos
        int64_t timestamp
        int flags
        int size
        int min_distance
    
    struct AVMetadataConv:
        pass
    
    struct AVMetadata:
        pass
    
    struct AVCodecTag:
        pass
    
    enum AVStreamParseType:
        AVSTREAM_PARSE_NONE,
        AVSTREAM_PARSE_FULL,       #< full parsing and repack */
        AVSTREAM_PARSE_HEADERS,    #< Only parse headers, do not repack. */
        AVSTREAM_PARSE_TIMESTAMPS, #< full parsing and interpolation of timestamps for frames not starting on a packet boundary */
        AVSTREAM_PARSE_FULL_ONCE    
    
    struct AVPacketList:
        AVPacket pkt
        AVPacketList *next

    struct AVOutputFormat:
        char *name
        char *long_name
        char *mime_type
        char *extensions
        int priv_data_size
        CodecID video_codec
        CodecID audio_codec
        int *write_header
        int *write_packet
        int *write_trailer
        # can use flags: AVFMT_NOFILE, AVFMT_NEEDNUMBER, AVFMT_RAWPICTURE,
        # AVFMT_GLOBALHEADER, AVFMT_NOTIMESTAMPS, AVFMT_VARIABLE_FPS,
        # AVFMT_NODIMENSIONS, AVFMT_NOSTREAMS
        int flags
        int *set_parameters        
        int *interleave_packet
        AVCodecTag **codec_tag
        CodecID subtitle_codec
        AVMetadataConv *metadata_conv
        void *priv_class
        AVOutputFormat *next

    struct AVInputFormat:
        char *name            #< A comma separated list of short names for the format
        char *long_name       #< Descriptive name for the format, meant to be more human-readable than name  
        int priv_data_size    #< Size of private data so that it can be allocated in the wrapper    
        char *mime_type       #< 
        int *read_probe
        int *read_header
        int *read_packet
        int *read_close
        int *read_seek
        int64_t *read_timestamp
        int flags
        char *extensions       #< If extensions are defined, then no probe is done
        int value
        int *read_play
        int *read_pause
        AVCodecTag **codec_tag        
        int *read_seek2
        AVMetadataConv *metadata_conv
        AVInputFormat *next


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
        int64_t first_dts # was codec_info_duration
        AVFrac pts
        # this is the fundamental unit of time (in seconds) in terms
        # of which frame timestamps are represented. for fixed-fps content,
        # timebase should be 1/framerate and timestamp increments should be
        # identically 1.
        AVRational time_base
        int pts_wrap_bits # number of bits in pts (used for wrapping control)
        # ffmpeg.c private use
        int stream_copy   # if TRUE, just copy Track
        AVDiscard discard       # < selects which packets can be discarded at will and dont need to be demuxed
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
        AVStreamParseType need_parsing                  # < 1.full parsing needed, 2.only parse headers dont repack
        AVCodecParserContext *parser
        int64_t cur_dts
        int last_IP_duration
        int64_t last_IP_pts
        # av_seek_frame() support
        AVIndexEntry *index_entries # only used if the format does not support seeking natively
        int nb_index_entries
        int index_entries_allocated_size
        int64_t nb_frames                 # < number of frames in this Track if known or 0
        int64_t unused[4+1]        
        char *filename                  #< source filename of the stream 
        int disposition
        AVProbeData probe_data
        int64_t pts_buffer[16+1]
        AVRational sample_aspect_ratio
        AVMetadata *metadata
        uint8_t *cur_ptr
        int cur_len
        AVPacket cur_pkt
        int64_t reference_dts
        int probe_packets
        AVPacketList *last_in_packet_buffer
        AVRational avg_frame_rate        
        int codec_info_nb_frames
        pass

    enum:
        # for AVFormatContext.streams
        MAX_STREAMS = 20

        # for AVFormatContext.flags
        AVFMT_FLAG_GENPTS      = 0x0001 #< Generate missing pts even if it requires parsing future frames.
        AVFMT_FLAG_IGNIDX      = 0x0002 #< Ignore index.
        AVFMT_FLAG_NONBLOCK    = 0x0004 #< Do not block when reading packets from input.
        AVFMT_FLAG_IGNDTS      = 0x0008 #< Ignore DTS on frames that contain both DTS & PTS
        AVFMT_FLAG_NOFILLIN    = 0x0010 #< Do not infer any values from other values, just return what is stored in the container
        AVFMT_FLAG_NOPARSE     = 0x0020 #< Do not use AVParsers, you also must set AVFMT_FLAG_NOFILLIN as the fillin code works on frames and no parsing -> no frames. Also seeking to frames can not work if parsing to find frame boundaries has been disabled
        AVFMT_FLAG_RTP_HINT    = 0x0040 #< Add RTP hinting to the output file


    struct AVPacketList:
        pass


    struct AVProgram:
        pass


    struct AVChapter:
        pass


    struct AVFormatContext:
        void *              av_class
        AVInputFormat *     iformat
        AVOutputFormat *    oformat
        void *              priv_data
        AVIOContext *       pb
        unsigned int        nb_streams
        AVStream *          streams[20]        #< MAX_STREAMS == 20
        char                filename[1024]
        int64_t             timestamp
        int                 ctx_flags        #< Format-specific flags, see AVFMTCTX_xx, private data for pts handling (do not modify directly)
        AVPacketList *      packet_buffer
        int64_t             start_time
        int64_t             duration
        int64_t             file_size        # decoding: total file size. 0 if unknown
        int                 bit_rate        # decoding: total Track bitrate in bit/s, 0 if not

        #  av_read_frame() support
        AVStream *cur_st
        uint8_t *cur_ptr_deprecated
        int cur_len_deprecated
        AVPacket cur_pkt_deprecated
        int64_t data_offset #< offset of the first packet 
        int index_built
        
        int mux_rate
        unsigned int packet_size
        int preload
        int max_delay
        int loop_output
        int flags                         #< see AVFMT_FLAG_xxx
        int loop_input
        unsigned int probesize            #< decoding: size of data to probe; encoding: unused.
        int max_analyze_duration          #<  Maximum time (in AV_TIME_BASE units) during which the input should be analyzed in av_find_stream_info()
        uint8_t *key        
        int keylen
        unsigned int nb_programs
        AVProgram **programs
        CodecID video_codec_id            #< Demuxing: Set by user. Forced video codec_id
        CodecID audio_codec_id            #< Demuxing: Set by user. Forced audio codec_id
        CodecID subtitle_codec_id         #< Demuxing: Set by user. Forced subtitle codec_id
        #     * Maximum amount of memory in bytes to use for the index of each stream.
        #     * If the index exceeds this size, entries will be discarded as
        #     * needed to maintain a smaller size. This can lead to slower or less
        #     * accurate seeking (depends on demuxer).
        #     * Demuxers for which a full in-memory index is mandatory will ignore
        #     * this.
        #     * muxing  : unused
        #     * demuxing: set by user
        unsigned int max_index_size
        #     * Maximum amount of memory in bytes to use for buffering frames
        #     * obtained from realtime capture devices.
        unsigned int max_picture_buffer

        unsigned int nb_chapters
        AVChapter **chapters

        int debug                            #< FF_FDEBUG_TS        0x0001

        AVPacketList *raw_packet_buffer
        AVPacketList *raw_packet_buffer_end
        AVPacketList *packet_buffer_end
        
        AVMetadata *metadata
        
        int raw_packet_buffer_remaining_size
        
        int64_t start_time_realtime        
        
        
    struct AVInputFormat:
        pass


    struct AVFormatParameters:
        pass


    AVOutputFormat *av_guess_format(char *short_name,
                                char *filename,
                                char *mime_type)

    CodecID av_guess_codec(AVOutputFormat *fmt, char *short_name,
                           char *filename, char *mime_type,
                           AVMediaType type)

    # * Initialize libavformat and register all the muxers, demuxers and
    # * protocols. If you do not call this function, then you can select
    # * exactly which formats you want to support.
    void av_register_all()
    
    # * Find AVInputFormat based on the short name of the input format.
    AVInputFormat *av_find_input_format(char *short_name)

    # * Guess the file format.
    # *
    # * @param is_opened Whether the file is already opened; determines whether
    # *                  demuxers with or without AVFMT_NOFILE are probed.
    AVInputFormat *av_probe_input_format(AVProbeData *pd, int is_opened)

    # * Guess the file format.
    # *
    # * @param is_opened Whether the file is already opened; determines whether
    # *                  demuxers with or without AVFMT_NOFILE are probed.
    # * @param score_max A probe score larger that this is required to accept a
    # *                  detection, the variable is set to the actual detection
    # *                  score afterwards.
    # *                  If the score is <= AVPROBE_SCORE_MAX / 4 it is recommended
    # *                  to retry with a larger probe buffer.
    AVInputFormat *av_probe_input_format2(AVProbeData *pd, int is_opened, int *score_max)

    # * Allocate all the structures needed to read an input stream.
    # *        This does not open the needed codecs for decoding the stream[s].
    int av_open_input_stream(AVFormatContext **ic_ptr,
                         AVIOContext *pb, char *filename,
                         AVInputFormat *fmt, AVFormatParameters *ap)

    # * Open a media file as input. The codecs are not opened. Only the file
    # * header (if present) is read.
    # *
    # * @param ic_ptr The opened media file handle is put here.
    # * @param filename filename to open
    # * @param fmt If non-NULL, force the file format to use.
    # * @param buf_size optional buffer size (zero if default is OK)
    # * @param ap Additional parameters needed when opening the file
    # *           (NULL if default).
    # * @return 0 if OK, AVERROR_xxx otherwise
    int av_open_input_file(AVFormatContext **ic_ptr, char *filename,
                       AVInputFormat *fmt, int buf_size,
                       AVFormatParameters *ap)

    # * Read packets of a media file to get stream information. This
    # * is useful for file formats with no headers such as MPEG. This
    # * function also computes the real framerate in case of MPEG-2 repeat
    # * frame mode.
    # * The logical file position is not changed by this function;
    # * examined packets may be buffered for later processing.
    # *
    # * @param ic media file handle
    # * @return >=0 if OK, AVERROR_xxx on error
    # * @todo Let the user decide somehow what information is needed so that
    # *       we do not waste time getting stuff the user does not need.
    int av_find_stream_info(AVFormatContext *ic)
    
    # * Read a transport packet from a media file.
    # *
    # * This function is obsolete and should never be used.
    # * Use av_read_frame() instead.
    # *
    # * @param s media file handle
    # * @param pkt is filled
    # * @return 0 if OK, AVERROR_xxx on error
    int av_read_packet(AVFormatContext *s, AVPacket *pkt)
 
    # * Return the next frame of a stream.
    # * This function returns what is stored in the file, and does not validate
    # * that what is there are valid frames for the decoder. It will split what is
    # * stored in the file into frames and return one for each call. It will not
    # * omit invalid data between valid frames so as to give the decoder the maximum
    # * information possible for decoding.
    # *
    # * The returned packet is valid
    # * until the next av_read_frame() or until av_close_input_file() and
    # * must be freed with av_free_packet. For video, the packet contains
    # * exactly one frame. For audio, it contains an integer number of
    # * frames if each frame has a known fixed size (e.g. PCM or ADPCM
    # * data). If the audio frames have a variable size (e.g. MPEG audio),
    # * then it contains one frame.
    # *
    # * pkt->pts, pkt->dts and pkt->duration are always set to correct
    # * values in AVStream.time_base units (and guessed if the format cannot
    # * provide them). pkt->pts can be AV_NOPTS_VALUE if the video format
    # * has B-frames, so it is better to rely on pkt->dts if you do not
    # * decompress the payload.
    # *
    # * @return 0 if OK, < 0 on error or end of file
    int av_read_frame(AVFormatContext *s, AVPacket *pkt)
    
    # * Seek to the keyframe at timestamp.
    # * 'timestamp' in 'stream_index'.
    # * @param stream_index If stream_index is (-1), a default
    # * stream is selected, and timestamp is automatically converted
    # * from AV_TIME_BASE units to the stream specific time_base.
    # * @param timestamp Timestamp in AVStream.time_base units
    # *        or, if no stream is specified, in AV_TIME_BASE units.
    # * @param flags flags which select direction and seeking mode
    # * @return >= 0 on success
    int av_seek_frame(AVFormatContext *s, int stream_index, int64_t timestamp,
                  int flags)
    
    # * Start playing a network-based stream (e.g. RTSP stream) at the
    # * current position.
    int av_read_play(AVFormatContext *s)

    # * Pause a network-based stream (e.g. RTSP stream).
    # * Use av_read_play() to resume it.
    int av_read_pause(AVFormatContext *s)
    
    # * Free a AVFormatContext allocated by av_open_input_stream.
    # * @param s context to free
    void av_close_input_stream(AVFormatContext *s)

    # * Close a media file (but not its codecs).
    # * @param s media file handle
    void av_close_input_file(AVFormatContext *s)

    # * Add a new stream to a media file.
    # *
    # * Can only be called in the read_header() function. If the flag
    # * AVFMTCTX_NOHEADER is in the format context, then new streams
    # * can be added in read_packet too.
    # *
    # * @param s media file handle
    # * @param id file-format-dependent stream ID
    AVStream *av_new_stream(AVFormatContext *s, int id)
    AVProgram *av_new_program(AVFormatContext *s, int id)

    
    int av_find_default_stream_index(AVFormatContext *s)
    
    # * Get the index for a specific timestamp.
    # * @param flags if AVSEEK_FLAG_BACKWARD then the returned index will correspond
    # *                 to the timestamp which is <= the requested one, if backward
    # *                 is 0, then it will be >=
    # *              if AVSEEK_FLAG_ANY seek to any frame, only keyframes otherwise
    # * @return < 0 if no such timestamp could be found
    int av_index_search_timestamp(AVStream *st, int64_t timestamp, int flags)    

    # * Add an index entry into a sorted list. Update the entry if the list
    # * already contains it.
    # *
    # * @param timestamp timestamp in the time base of the given stream
    int av_add_index_entry(AVStream *st, int64_t pos, int64_t timestamp,
                       int size, int distance, int flags)

    # * Perform a binary search using av_index_search_timestamp() and
    # * AVInputFormat.read_timestamp().
    # * This is not supposed to be called directly by a user application,
    # * but by demuxers.
    # * @param target_ts target timestamp in the time base of the given stream
    # * @param stream_index stream number
    int av_seek_frame_binary(AVFormatContext *s, int stream_index,
                         int64_t target_ts, int flags)

    
    void av_dump_format(AVFormatContext *ic,
                    int index,
                    char *url,
                    int is_output)

    # * Allocate an AVFormatContext.
    # * avformat_free_context() can be used to free the context and everything
    # * allocated by the framework within it.
    AVFormatContext *avformat_alloc_context()


##################################################################################
# ok libswscale    0. 12. 0 
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

    # deprecated use sws_alloc_context() and sws_init_context()
    SwsContext *sws_getContext(int srcW, int srcH, int srcFormat, int dstW, int dstH, int dstFormat, int flags,SwsFilter *srcFilter, SwsFilter *dstFilter, double *param)
    #SwsContext *sws_alloc_context()
    #int sws_init_context(struct SwsContext *sws_context, SwsFilter *srcFilter, SwsFilter *dstFilter)
    void sws_freeContext(SwsContext *swsContext)
    int sws_scale(SwsContext *context, uint8_t* src[], int srcStride[], int srcSliceY,int srcSliceH, uint8_t* dst[], int dstStride[])


##################################################################################
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


##################################################################################
# General includes
##################################################################################
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


##################################################################################
# Utility elements
##################################################################################


# original definiton as define in libavutil/avutil.h
cdef AVRational AV_TIME_BASE_Q
AV_TIME_BASE_Q.num = 1
AV_TIME_BASE_Q.den = AV_TIME_BASE

AVFMT_NOFILE = 1

cdef av_read_frame_flush(AVFormatContext *s):
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

# originally defined in mpegvideo.h
def IS_INTRA4x4(mb_type):
    return ((mb_type & MB_TYPE_INTRA4x4)>0)*1
def IS_INTRA16x16(mb_type):
    return ((mb_type & MB_TYPE_INTRA16x16)>0)*1
def IS_INTRA4x4(a):
    return (((a)&MB_TYPE_INTRA4x4)>0)*1
def IS_INTRA16x16(a):
    return (((a)&MB_TYPE_INTRA16x16)>0)*1
def IS_PCM(a):        
    return (((a)&MB_TYPE_INTRA_PCM)>0)*1
def IS_INTRA(a):      
    return (((a)&7)>0)*1
def IS_INTER(a):      
    return (((a)&(MB_TYPE_16x16|MB_TYPE_16x8|MB_TYPE_8x16|MB_TYPE_8x8))>0)*1
def IS_SKIP(a):       
    return (((a)&MB_TYPE_SKIP)>0)*1
def IS_INTRA_PCM(a):  
    return (((a)&MB_TYPE_INTRA_PCM)>0)*1
def IS_INTERLACED(a): 
    return (((a)&MB_TYPE_INTERLACED)>0)*1
def IS_DIRECT(a):     
    return (((a)&MB_TYPE_DIRECT2)>0)*1
def IS_GMC(a):        
    return (((a)&MB_TYPE_GMC)>0)*1
def IS_16x16(a):      
    return (((a)&MB_TYPE_16x16)>0)*1
def IS_16x8(a):       
    return (((a)&MB_TYPE_16x8)>0)*1
def IS_8x16(a):       
    return (((a)&MB_TYPE_8x16)>0)*1
def IS_8x8(a):        
    return (((a)&MB_TYPE_8x8)>0)*1
def IS_SUB_8x8(a):    
    return (((a)&MB_TYPE_16x16)>0)*1 #note reused
def IS_SUB_8x4(a):    
    return (((a)&MB_TYPE_16x8)>0)*1  #note reused
def IS_SUB_4x8(a):    
    return (((a)&MB_TYPE_8x16)>0)*1  #note reused
def IS_SUB_4x4(a):    
    return (((a)&MB_TYPE_8x8)>0)*1   #note reused
def IS_DIR(a, part, whichlist):
    return (((a) & (MB_TYPE_P0L0<<((part)+2*(whichlist))))>0)*1
def USES_LIST(a, whichlist):
    return (((a) & ((MB_TYPE_P0L0|MB_TYPE_P1L0)<<(2*(whichlist))))>0)*1 #< does this mb use listX, note does not work if subMBs


##################################################################################
## AudioQueue Object  (This may later be exported with another object)
##################################################################################
cdef DEBUG(s):
    sys.stderr.write("DEBUG: %s\n"%(s,))
    sys.stderr.flush()

## contains pairs of timestamp, array
try:
    from audioqueue import AudioQueue, Queue_Empty, Queue_Full
except:
    pass


##################################################################################
# Initialization
##################################################################################

cdef __registered
__registered = 0
if not __registered:
    __registered = 1
    av_register_all()


##################################################################################
# Some default settings
##################################################################################
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
    cdef AVIOContext *io_context
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

    def __cinit__(self):
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
            # discard all frames except keyframes
            self.CodecCtx.skip_loop_filter = AVDISCARD_NONKEY
            self.CodecCtx.skip_frame = AVDISCARD_NONKEY
            self.CodecCtx.skip_idct = AVDISCARD_NONKEY
            # deprecated
            # 1-> Skip B-frames, 2-> Skip IDCT/dequant too, 5-> Skip everything except header
            self.CodecCtx.hurry_up=2  
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
        if not args.has_key("check_start"): 
            self.do_check_start=1
        else:
            self.do_check_start=args["check_start"]
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
        len1 = avcodec_decode_audio3(aCodecCtx, <int16_t *>audio_buf, &data_size, pkt)
        if(len1 < 0) :
                raise IOError,("Audio decoding error (i)",len1)
        if(data_size < 0) :
                raise IOError,("Audio decoding error (ii)",data_size)

        #We have data, return it and come back for more later */
        pts = audio_clock[0]
        pts_ptr[0] = pts
        n = 2 * nchannels
        audio_clock[0] += ((<double>data_size) / (<double>(n * samplerate)))
        return data_size


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
        #while or if? (see version 2.0)
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
    cdef PixelFormat pixel_format
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




    def init(self, pixel_format=PIX_FMT_NONE, videoframebanksz=1, dest_width=-1, dest_height=-1,videobuffers=2,outputmode=OUTPUTMODE_NUMPY,with_motion_vectors=0,** args):
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
        if (self.pixel_format==PIX_FMT_NONE):
            self.pixel_format=PIX_FMT_RGB24
        self.videoframebank=[]
        self.videoframebanksz=videoframebanksz
        self.videobuffers=videobuffers
        self.with_motion_vectors=with_motion_vectors
        if self.with_motion_vectors:
            self.CodecCtx.debug = FF_DEBUG_MV | FF_DEBUG_MB_TYPE        
        self.width = self.CodecCtx.width
        self.height = self.CodecCtx.height
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


    cdef _read_current_macroblock_types(self, AVFrame *f):
        cdef int mb_width
        cdef int mb_height
        cdef int mb_stride

        mb_width = (self.width+15)>>4
        mb_height = (self.height+15)>>4
        mb_stride = mb_width + 1

        #if (self.CodecCtx.codec_id == CODEC_ID_MPEG2VIDEO) && (self.CodecCtx.progressive_sequence!=0)
        #    mb_height = (self.height + 31) / 32 * 2
        #elif self.CodecCtx.codec_id != CODEC_ID_H264
        #    mb_height = self.height + 15) / 16;

        res = numpy.zeros((mb_height,mb_width), dtype=numpy.uint32)

        if ((<void*>f.mb_type)==NULL):
            print "no mb_type available"
            return None           

        cdef int x,y
        for x in range(mb_width):
            for y in range(mb_height):
                res[y,x]=f.mb_type[x + y*mb_stride]
        return res


    cdef _read_current_motion_vectors(self,AVFrame * f):
        cdef int mv_sample_log2
        cdef int mb_width
        cdef int mb_height
        cdef int mv_stride

        mv_sample_log2 = 4 - f.motion_subsample_log2
        mb_width = (self.width+15)>>4
        mb_height = (self.height+15)>>4
        mv_stride = (mb_width << mv_sample_log2)
        if self.CodecCtx.codec_id != CODEC_ID_H264:
            mv_stride += 1
        res = numpy.zeros((mb_height<<mv_sample_log2,mb_width<<mv_sample_log2,2), dtype=numpy.int16)

        # TODO: support also backward prediction
        
        if ((<void*>f.motion_val[0])==NULL):
            print "no motion_val available"
            return None
        
        cdef int x,y,xydirection,preddirection    
        preddirection = 0
        for xydirection in range(2):
            for x in range(2*mb_width):
                for y in range(2*mb_height):
                    res[y,x,xydirection]=f.motion_val[preddirection][x + y*mv_stride][xydirection]
        return res


    cdef _read_current_ref_index(self, AVFrame *f):
        # HAS TO BE DEBUGGED
        cdef int mv_sample_log2
        cdef int mv_width
        cdef int mv_height
        cdef int mv_stride

        mv_sample_log2= 4 - f.motion_subsample_log2
        mb_width= (self.width+15)>>4
        mb_height= (self.height+15)>>4
        mv_stride= (mb_width << mv_sample_log2) + 1
        res = numpy.zeros((mb_height,mb_width,2), dtype=numpy.int8)

        # currently only forward predicition is supported
        if ((<void*>f.ref_index[0])==NULL):
            print "no ref_index available"
            return None

        cdef int x,y,xydirection,preddirection,mb_stride
        mb_stride = mb_width + 1
        
#00524     s->mb_stride = mb_width + 1;
#00525     s->b8_stride = s->mb_width*2 + 1;
#00526     s->b4_stride = s->mb_width*4 + 1;

        # currently only forward predicition is supported
        preddirection = 0
        for xydirection in range(2):
            for x in range(mb_width):
                for y in range(mb_height):
                     res[y,x]=f.ref_index[preddirection][x + y*mb_stride]
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
        self.pts = av_rescale(pts,AV_TIME_BASE * <int64_t>self.stream.time_base.num,self.stream.time_base.den)
        #print "unparsed pts", pts,  self.stream.time_base.num,self.stream.time_base.den,  self.pts
        self.frameno += 1
        pict_type = self.frame.pict_type
        if (self.with_motion_vectors):
            motion_vals = self._read_current_motion_vectors(self.frame)
            mb_type = self._read_current_macroblock_types(self.frame)
            ref_index = self._read_current_ref_index(self.frame)
        else:
            motion_vals = None
            mb_type = None
            ref_index = None
        self.videoframebank.append((self.pts, 
                                    self.frameno,
                                    self._internal_get_current_frame(),
                                    pict_type,
                                    mb_type,
                                    motion_vals,
                                    ref_index))
        # DEBUG this
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
            self.CodecCtx.skip_idct = AVDISCARD_DEFAULT
            self.CodecCtx.skip_frame = AVDISCARD_DEFAULT
            self.CodecCtx.hurry_up = 0

    ########################################
    ###
    ########################################


    cdef AVFrame *_convert_to(self,AVPicture *frame, PixelFormat pixformat=PIX_FMT_NONE):
        """ Convert AVFrame to a specified format (Intended for copy) """

        cdef AVFrame *pFrame
        cdef int numBytes
        cdef char *rgb_buffer
        cdef int width,height
        cdef AVCodecContext *pCodecCtx = self.CodecCtx

        if (pixformat==PIX_FMT_NONE):
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






    cdef AVFrame *_convert_withbuf(self,AVPicture *frame,char *buf,  PixelFormat pixformat=PIX_FMT_NONE):
        """ Convert AVFrame to a specified format (Intended for copy)  """

        cdef AVFrame *pFramePixFormat
        cdef int numBytes
        cdef int width,height
        cdef AVCodecContext *pCodecCtx = self.CodecCtx

        if (pixformat==PIX_FMT_NONE):
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
        """ return the smallest time index among the not yet displayed decoded frame """
        try:
            return self.smallest_videobank_time()
        except:
            self.__next_frame()
            return self.smallest_videobank_time()

    def get_current_frame_pts(self):
        """ return the PTS for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][0]

    def get_current_frame_frameno(self):
        """ return the frame number for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][1]

    def get_current_frame_type(self):
        """ return the pict_type for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][3]

    def get_current_frame_macroblock_types(self):
        """ return the motion_vals for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][4]        

    def get_current_frame_motion_vectors(self):
        """ return the motion_vals for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][5]        

    def get_current_frame_reference_index(self):
        """ return the motion_vals for the frame with the smallest time index 
        among the not yet displayed decoded frame """
        am=self.safe_smallest_videobank_time()
        return self.videoframebank[am][6]        

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

    def __cinit__(self,with_readahead=True,seek_before=4000):
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
        av_dump_format(self.FormatCtx,0,self.filename,0)


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
            self.FormatCtx.oformat = av_guess_format(NULL, filename_, NULL)
            if (self.FormatCtx.oformat==NULL):
                raise Exception, "Unable to find output format for %s\n"

        if (fmt==NULL):
            fmt=av_probe_input_format(&pd,0)
        
        if (fmt==NULL) or (not (fmt.flags & AVFMT_NOFILE)):
            ret = avio_open(&self.FormatCtx.pb, filename, 0)
            if ret < 0:
                raise IOError("Unable to open file %s (avio_open)" % filename)
            if (buf_size>0):
                url_setbufsize(self.FormatCtx.pb,buf_size)
            #raise Exception, "Not Yet Implemented"
            for log2_probe_size in range(11,20):
                probe_size=1<<log2_probe_size
                #score=(AVPROBE_SCORE_MAX/4 if log2_probe_size!=20 else 0)
                pd.buf=<unsigned char *>av_realloc(pd.buf,probe_size+AVPROBE_PADDING_SIZE)
                pd.buf_size=avio_read(self.FormatCtx.pb,pd.buf,probe_size)
                memset(pd.buf+pd.buf_size,0,AVPROBE_PADDING_SIZE)
                if (avio_seek(self.FormatCtx.pb,0,SEEK_SET)):
                    avio_close(self.FormatCtx.pb)
                    ret=avio_open(&self.FormatCtx.pb, filename, 0)
                    if (ret < 0):
                        raise IOError("Unable to open file %s (avio_open with but)" % filename)
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
            ret=avio_open(&self.FormatCtx.pb, filename, 1)
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
        oc.oformat = av_guess_format(NULL, filename_, NULL)
        if (oc.oformat==NULL):
            raise Exception, "Unable to find output format for %s\n"
        # Alloc priv_data for format
        oc.priv_data = av_mallocz(oc.oformat.priv_data_size)
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
        avio_open(&oc.pb, filename_, URL_WRONLY)

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
        av_read_frame_flush(self.FormatCtx)
        ret = av_seek_frame(self.FormatCtx,-1,byte,  AVSEEK_FLAG_BACKWARD|AVSEEK_FLAG_BYTE)#|AVSEEK_FLAG_ANY)
        if ret < 0:
            raise IOError("Unable to seek: %d" % (ret,))
        if (self.io_context!=NULL):
            # used to have & here
            avio_seek(self.FormatCtx.pb, self.FormatCtx.data_offset, SEEK_SET)
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
#        if (avio_open(&self.io_context, filename,URL_RDONLY ) < 0):
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




##################################################################################
# Legacy support for compatibility with PyFFmpeg version 1.0
##################################################################################
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


##################################################################################
# Usefull constants
##################################################################################

##################################################################################
# ok libavcodec   52.113. 2
# defined in libavcodec/avcodec.h for AVCodecContext.profile
class profileTypes:
    FF_PROFILE_UNKNOWN  = -99
    FF_PROFILE_RESERVED = -100

    FF_PROFILE_AAC_MAIN = 0
    FF_PROFILE_AAC_LOW  = 1
    FF_PROFILE_AAC_SSR  = 2
    FF_PROFILE_AAC_LTP  = 3

    FF_PROFILE_DTS         = 20
    FF_PROFILE_DTS_ES      = 30
    FF_PROFILE_DTS_96_24   = 40
    FF_PROFILE_DTS_HD_HRA  = 50
    FF_PROFILE_DTS_HD_MA   = 60

    FF_PROFILE_MPEG2_422    = 0
    FF_PROFILE_MPEG2_HIGH   = 1
    FF_PROFILE_MPEG2_SS     = 2
    FF_PROFILE_MPEG2_SNR_SCALABLE  = 3
    FF_PROFILE_MPEG2_MAIN   = 4
    FF_PROFILE_MPEG2_SIMPLE = 5

    FF_PROFILE_H264_CONSTRAINED = (1<<9)  # 8+1; constraint_set1_flag
    FF_PROFILE_H264_INTRA       = (1<<11) # 8+3; constraint_set3_flag

    FF_PROFILE_H264_BASELINE             = 66
    FF_PROFILE_H264_CONSTRAINED_BASELINE = (66|FF_PROFILE_H264_CONSTRAINED)
    FF_PROFILE_H264_MAIN                 = 77
    FF_PROFILE_H264_EXTENDED             = 88
    FF_PROFILE_H264_HIGH                 = 100
    FF_PROFILE_H264_HIGH_10              = 110
    FF_PROFILE_H264_HIGH_10_INTRA        = (110|FF_PROFILE_H264_INTRA)
    FF_PROFILE_H264_HIGH_422             = 122
    FF_PROFILE_H264_HIGH_422_INTRA       = (122|FF_PROFILE_H264_INTRA)
    FF_PROFILE_H264_HIGH_444             = 144
    FF_PROFILE_H264_HIGH_444_PREDICTIVE  = 244
    FF_PROFILE_H264_HIGH_444_INTRA       = (244|FF_PROFILE_H264_INTRA)
    FF_PROFILE_H264_CAVLC_444            = 44
  

##################################################################################
# ok libavcodec   52.113. 2
class CodecTypes:
    CODEC_TYPE_UNKNOWN     = -1
    CODEC_TYPE_VIDEO       = 0
    CODEC_TYPE_AUDIO       = 1
    CODEC_TYPE_DATA        = 2
    CODEC_TYPE_SUBTITLE    = 3
    CODEC_TYPE_ATTACHMENT  = 4

##################################################################################
# ok libavutil    50. 39. 0
class mbTypes:
    MB_TYPE_INTRA4x4   = 0x0001
    MB_TYPE_INTRA16x16 = 0x0002 #FIXME H.264-specific
    MB_TYPE_INTRA_PCM  = 0x0004 #FIXME H.264-specific
    MB_TYPE_16x16      = 0x0008
    MB_TYPE_16x8       = 0x0010
    MB_TYPE_8x16       = 0x0020
    MB_TYPE_8x8        = 0x0040
    MB_TYPE_INTERLACED = 0x0080
    MB_TYPE_DIRECT2    = 0x0100 #FIXME
    MB_TYPE_ACPRED     = 0x0200
    MB_TYPE_GMC        = 0x0400
    MB_TYPE_SKIP       = 0x0800
    MB_TYPE_P0L0       = 0x1000
    MB_TYPE_P1L0       = 0x2000
    MB_TYPE_P0L1       = 0x4000
    MB_TYPE_P1L1       = 0x8000
    MB_TYPE_L0         = (MB_TYPE_P0L0 | MB_TYPE_P1L0)
    MB_TYPE_L1         = (MB_TYPE_P0L1 | MB_TYPE_P1L1)
    MB_TYPE_L0L1       = (MB_TYPE_L0   | MB_TYPE_L1)
    MB_TYPE_QUANT      = 0x00010000
    MB_TYPE_CBP        = 0x00020000    

##################################################################################
# ok
class PixelFormats:
    PIX_FMT_NONE                    = -1
    PIX_FMT_YUV420P                 = 0
    PIX_FMT_YUYV422                 = 1
    PIX_FMT_RGB24                   = 2   
    PIX_FMT_BGR24                   = 3   
    PIX_FMT_YUV422P                 = 4   
    PIX_FMT_YUV444P                 = 5   
    PIX_FMT_YUV410P                 = 6   
    PIX_FMT_YUV411P                 = 7   
    PIX_FMT_GRAY8                   = 8   
    PIX_FMT_MONOWHITE               = 9 
    PIX_FMT_MONOBLACK               = 10 
    PIX_FMT_PAL8                    = 11    
    PIX_FMT_YUVJ420P                = 12 
    PIX_FMT_YUVJ422P                = 13  
    PIX_FMT_YUVJ444P                = 14  
    PIX_FMT_XVMC_MPEG2_MC           = 15
    PIX_FMT_XVMC_MPEG2_IDCT         = 16
    PIX_FMT_UYVY422                 = 17
    PIX_FMT_UYYVYY411               = 18
    PIX_FMT_BGR8                    = 19  
    PIX_FMT_BGR4                    = 20    
    PIX_FMT_BGR4_BYTE               = 21
    PIX_FMT_RGB8                    = 22     
    PIX_FMT_RGB4                    = 23     
    PIX_FMT_RGB4_BYTE               = 24
    PIX_FMT_NV12                    = 25     
    PIX_FMT_NV21                    = 26     

    PIX_FMT_ARGB                    = 27     
    PIX_FMT_RGBA                    = 28     
    PIX_FMT_ABGR                    = 29     
    PIX_FMT_BGRA                    = 30     

    PIX_FMT_GRAY16BE                = 31 
    PIX_FMT_GRAY16LE                = 32 
    PIX_FMT_YUV440P                 = 33 
    PIX_FMT_YUVJ440P                = 34 
    PIX_FMT_YUVA420P                = 35
    PIX_FMT_VDPAU_H264              = 36
    PIX_FMT_VDPAU_MPEG1             = 37
    PIX_FMT_VDPAU_MPEG2             = 38
    PIX_FMT_VDPAU_WMV3              = 39
    PIX_FMT_VDPAU_VC1               = 40
    PIX_FMT_RGB48BE                 = 41  
    PIX_FMT_RGB48LE                 = 42  

    PIX_FMT_RGB565BE                = 43 
    PIX_FMT_RGB565LE                = 44 
    PIX_FMT_RGB555BE                = 45 
    PIX_FMT_RGB555LE                = 46 

    PIX_FMT_BGR565BE                = 47 
    PIX_FMT_BGR565LE                = 48 
    PIX_FMT_BGR555BE                = 49 
    PIX_FMT_BGR555LE                = 50 

    PIX_FMT_VAAPI_MOCO              = 51
    PIX_FMT_VAAPI_IDCT              = 52
    PIX_FMT_VAAPI_VLD               = 53 

    PIX_FMT_YUV420P16LE             = 54 
    PIX_FMT_YUV420P16BE             = 55 
    PIX_FMT_YUV422P16LE             = 56 
    PIX_FMT_YUV422P16BE             = 57 
    PIX_FMT_YUV444P16LE             = 58 
    PIX_FMT_YUV444P16BE             = 59 
    PIX_FMT_VDPAU_MPEG4             = 60 
    PIX_FMT_DXVA2_VLD               = 61 

    PIX_FMT_RGB444BE                = 62
    PIX_FMT_RGB444LE                = 63 
    PIX_FMT_BGR444BE                = 64 
    PIX_FMT_BGR444LE                = 65 
    PIX_FMT_Y400A                   = 66 
