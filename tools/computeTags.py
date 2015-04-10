def param_convert(a):
	if type(a)==str:
		comment = "'" + a + "'"
		a = ord(a)
	else:
		comment = str(a)
	return a, comment

def MKTAG(a,b,c,d):
	'''
	from libavutil/common.h
	'''
	comment = "MKTAG("
	a,_comment = param_convert(a)
	comment += _comment + ','
	b,_comment = param_convert(b)
	comment += _comment + ','
	c,_comment = param_convert(c)
	comment += _comment + ','
	d,_comment = param_convert(d)
	comment += _comment + ')'
	
	return ((a) | ((b) << 8) | ((c) << 16) | ((d) << 24)), comment

def MKBETAG(a,b,c,d):
	'''
	from libavutil/common.h
	'''
	comment = "MKBETAG("
	a,_comment = param_convert(a)
	comment += _comment + ','
	b,_comment = param_convert(b)
	comment += _comment + ','
	c,_comment = param_convert(c)
	comment += _comment + ','
	d,_comment = param_convert(d)
	comment += _comment + ')'

	return ((d) | ((c) << 8) | ((b) << 16) | ((a) << 24)), comment

def main():
	print "AV_CODEC_ID_BRENDER_PIX = 0x%x, # %s" % MKBETAG('B','P','I','X')
	print "AV_CODEC_ID_Y41P        = 0x%x, # %s" % MKBETAG('Y','4','1','P')
	print "AV_CODEC_ID_ESCAPE130   = 0x%x, # %s" % MKBETAG('E','1','3','0')
	print "AV_CODEC_ID_EXR         = 0x%x, # %s" % MKBETAG('0','E','X','R')
	print "AV_CODEC_ID_AVRP        = 0x%x, # %s" % MKBETAG('A','V','R','P')
	
	print ""

	print "AV_CODEC_ID_012V        = 0x%x, # %s" % MKBETAG('0','1','2','V')
	print "AV_CODEC_ID_G2M         = 0x%x, # %s" % MKBETAG( 0 ,'G','2','M')
	print "AV_CODEC_ID_AVUI        = 0x%x, # %s" % MKBETAG('A','V','U','I')
	print "AV_CODEC_ID_AYUV        = 0x%x, # %s" % MKBETAG('A','Y','U','V')
	print "AV_CODEC_ID_TARGA_Y216  = 0x%x, # %s" % MKBETAG('T','2','1','6')
	print "AV_CODEC_ID_V308        = 0x%x, # %s" % MKBETAG('V','3','0','8')
	print "AV_CODEC_ID_V408        = 0x%x, # %s" % MKBETAG('V','4','0','8')
	print "AV_CODEC_ID_YUV4        = 0x%x, # %s" % MKBETAG('Y','U','V','4')
	print "AV_CODEC_ID_SANM        = 0x%x, # %s" % MKBETAG('S','A','N','M')
	print "AV_CODEC_ID_PAF_VIDEO   = 0x%x, # %s" % MKBETAG('P','A','F','V')
	print "AV_CODEC_ID_AVRN        = 0x%x, # %s" % MKBETAG('A','V','R','n')
	print "AV_CODEC_ID_CPIA        = 0x%x, # %s" % MKBETAG('C','P','I','A')
	print "AV_CODEC_ID_XFACE       = 0x%x, # %s" % MKBETAG('X','F','A','C')
	print "AV_CODEC_ID_SGIRLE      = 0x%x, # %s" % MKBETAG('S','G','I','R')
	print "AV_CODEC_ID_MVC1        = 0x%x, # %s" % MKBETAG('M','V','C','1')
	print "AV_CODEC_ID_MVC2        = 0x%x, # %s" % MKBETAG('M','V','C','2')
	print "AV_CODEC_ID_SNOW        = 0x%x, # %s" % MKBETAG('S','N','O','W')
	print "AV_CODEC_ID_WEBP        = 0x%x, # %s" % MKBETAG('W','E','B','P')
	print "AV_CODEC_ID_SMVJPEG     = 0x%x, # %s" % MKBETAG('S','M','V','J')
	print "AV_CODEC_ID_HEVC        = 0x%x, # %s" % MKBETAG('H','2','6','5')
	print "AV_CODEC_ID_VP7         = 0x%x, # %s" % MKBETAG('V','P','7','0')
	print "AV_CODEC_ID_APNG        = 0x%x, # %s" % MKBETAG('A','P','N','G')

	print ""

	print "AV_CODEC_ID_PCM_S24LE_PLANAR= 0x%x, # %s" % MKBETAG(24,'P','S','P')
	print "AV_CODEC_ID_PCM_S32LE_PLANAR= 0x%x, # %s" % MKBETAG(32,'P','S','P')
	print "AV_CODEC_ID_PCM_S16BE_PLANAR= 0x%x, # %s" % MKBETAG('P','S','P',16)

	print ""

	print "AV_CODEC_ID_ADPCM_VIMA = 0x%x, # %s" % MKBETAG('V','I','M','A')
	print "AV_CODEC_ID_VIMA       = 0x%x, # %s" % MKBETAG('V','I','M','A')
	print "AV_CODEC_ID_ADPCM_AFC  = 0x%x, # %s" % MKBETAG('A','F','C',' ')
	print "AV_CODEC_ID_ADPCM_IMA_OKI = 0x%x, # %s" % MKBETAG('O','K','I',' ')
	print "AV_CODEC_ID_ADPCM_DTK  = 0x%x, # %s" % MKBETAG('D','T','K',' ')
	print "AV_CODEC_ID_ADPCM_IMA_RAD = 0x%x, # %s" % MKBETAG('R','A','D',' ')
	print "AV_CODEC_ID_ADPCM_G726LE = 0x%x, # %s" % MKBETAG('6','2','7','G')

	print ""

	print "AV_CODEC_ID_FFWAVESYNTH = 0x%x, # %s" % MKBETAG('F','F','W','S')
	print "AV_CODEC_ID_SONIC       = 0x%x, # %s" % MKBETAG('S','O','N','C')
	print "AV_CODEC_ID_SONIC_LS    = 0x%x, # %s" % MKBETAG('S','O','N','L')
	print "AV_CODEC_ID_PAF_AUDIO   = 0x%x, # %s" % MKBETAG('P','A','F','A')
	print "AV_CODEC_ID_OPUS        = 0x%x, # %s" % MKBETAG('O','P','U','S')
	print "AV_CODEC_ID_TAK         = 0x%x, # %s" % MKBETAG('t','B','a','K')
	print "AV_CODEC_ID_EVRC        = 0x%x, # %s" % MKBETAG('s','e','v','c')
	print "AV_CODEC_ID_SMV         = 0x%x, # %s" % MKBETAG('s','s','m','v')
	print "AV_CODEC_ID_DSD_LSBF    = 0x%x, # %s" % MKBETAG('D','S','D','L')
	print "AV_CODEC_ID_DSD_MSBF    = 0x%x, # %s" % MKBETAG('D','S','D','M')
	print "AV_CODEC_ID_DSD_LSBF_PLANAR = 0x%x, # %s" % MKBETAG('D','S','D','1')
	print "AV_CODEC_ID_DSD_MSBF_PLANAR = 0x%x, # %s" % MKBETAG('D','S','D','8')

	print ""

	print "AV_CODEC_ID_MICRODVD   = 0x%x, # %s" % MKBETAG('m','D','V','D')
	print "AV_CODEC_ID_EIA_608    = 0x%x, # %s" % MKBETAG('c','6','0','8')
	print "AV_CODEC_ID_JACOSUB    = 0x%x, # %s" % MKBETAG('J','S','U','B')
	print "AV_CODEC_ID_SAMI       = 0x%x, # %s" % MKBETAG('S','A','M','I')
	print "AV_CODEC_ID_REALTEXT   = 0x%x, # %s" % MKBETAG('R','T','X','T')
	print "AV_CODEC_ID_STL        = 0x%x, # %s" % MKBETAG('S','p','T','L')
	print "AV_CODEC_ID_SUBVIEWER1 = 0x%x, # %s" % MKBETAG('S','b','V','1')
	print "AV_CODEC_ID_SUBVIEWER  = 0x%x, # %s" % MKBETAG('S','u','b','V')
	print "AV_CODEC_ID_SUBRIP     = 0x%x, # %s" % MKBETAG('S','R','i','p')
	print "AV_CODEC_ID_WEBVTT     = 0x%x, # %s" % MKBETAG('W','V','T','T')
	print "AV_CODEC_ID_MPL2       = 0x%x, # %s" % MKBETAG('M','P','L','2')
	print "AV_CODEC_ID_VPLAYER    = 0x%x, # %s" % MKBETAG('V','P','l','r')
	print "AV_CODEC_ID_PJS        = 0x%x, # %s" % MKBETAG('P','h','J','S')
	print "AV_CODEC_ID_ASS        = 0x%x, # %s" % MKBETAG('A','S','S',' ')

	print ""

	print "AV_CODEC_ID_BINTEXT    = 0x%x, # %s" % MKBETAG('B','T','X','T')
	print "AV_CODEC_ID_XBIN       = 0x%x, # %s" % MKBETAG('X','B','I','N')
	print "AV_CODEC_ID_IDF        = 0x%x, # %s" % MKBETAG( 0 ,'I','D','F')
	print "AV_CODEC_ID_OTF        = 0x%x, # %s" % MKBETAG( 0 ,'O','T','F')
	print "AV_CODEC_ID_SMPTE_KLV  = 0x%x, # %s" % MKBETAG('K','L','V','A')
	print "AV_CODEC_ID_DVD_NAV    = 0x%x, # %s" % MKBETAG('D','N','A','V')
	print "AV_CODEC_ID_TIMED_ID3  = 0x%x, # %s" % MKBETAG('T','I','D','3')
	print "AV_CODEC_ID_BIN_DATA   = 0x%x, # %s" % MKBETAG('D','A','T','A')

	print 80*"-"
	
	print "AV_OPT_TYPE_IMAGE_SIZE = 0x%x, # %s" % MKBETAG('S','I','Z','E')
	print "AV_OPT_TYPE_PIXEL_FMT  = 0x%x, # %s" % MKBETAG('P','F','M','T')
	print "AV_OPT_TYPE_SAMPLE_FMT = 0x%x, # %s" % MKBETAG('S','F','M','T')
	print "AV_OPT_TYPE_VIDEO_RATE = 0x%x, # %s" % MKBETAG('V','R','A','T')
	print "AV_OPT_TYPE_DURATION   = 0x%x, # %s" % MKBETAG('D','U','R',' ')
	print "AV_OPT_TYPE_COLOR	  = 0x%x, # %s" % MKBETAG('C','O','L','R')
	print "AV_OPT_TYPE_CHANNEL_LAYOUT = 0x%x, # %s" % MKBETAG('C','H','L','A')

	print 80*"-"
	
	print "AVSTREAM_PARSE_FULL_RAW = 0x%x, # %s" % MKTAG(0,'R','A','W')


if __name__ == "__main__":
    main()