# -*- coding: utf-8 -*-
"""
check your PyFFmpeg installation 
"""

import pyffmpeg as pf

def testVideo():
    mp = pf.FFMpegReader()
    mp.open("test.mp4",pf.TS_VIDEO_PIL)
    vt=mp.get_tracks()[0]    # video track
    for k in xrange(0,10):
        image = vt.get_next_frame()
        image.save("test_%(number)03d.png" % {'number':k}, "PNG")   
    
if __name__ == "__main__":
    testVideo()