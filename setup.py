# -*- coding: utf-8 -*-
import os
from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
from os.path import join as path_join
from sys import platform




try:
  import numpy.distutils.misc_util as nd
  with_numpy=True
except:
  with_numpy=False
  sys.stderr.write("Numpy does not seems to be installed on your system.\n")
  sys.stderr.write("You may still use pyffmpeg but audiosupport and numpy-bridge are disabled.\n")  




## Try to locate source if necessary
if platform == 'win32':
    ffmpegpath = r'c:\ffmpeg'
    for x in [ r'..\ffmpeg',  r'c:\ffmpeg-static', r'c:\ffmpeg' ]:
        try:
             os.stat(x)
             ffmpegpath = x
        except:
            pass
    extra_compiler_args=["-static-libgcc"]
    
else:
    ffmpegpath = '/opt/ffmpeg'
    for x in [ os.environ["HOME"]+"build/ffmpeg",  '/usr/local/ffmpeg',  '/opt/ffmpeg' ]:
        try:
             os.stat(x)
             ffmpegpath = x
        except:
            pass    
    extra_compiler_args=[]


# Try to resove
# static dependencies resolution by looking into pkgconfig files
def static_resolver(libs):
    deps = []
    for lib in libs:
        try:
            pc = open(path_join(ffmpegpath, 'lib', 'pkgconfig', 'lib' + lib + '.pc'))
        except IOError:
            continue

        # we only need line starting with 'Libs:'
        l = filter(lambda x: x.startswith('Libs:'), pc).pop().strip()

        # we only need after '-lmylib' and one entry for library
        d = l.split(lib, 1).pop().split()

        # remove '-l'
        d = map(lambda x: x[2:], d)

        # empty list means no deps
        if len(d): deps += d

    # Unique list
    result = list(libs)
    map(lambda x: x not in result and result.append(x), deps)
    return result


libs = [ 'avformat', 'avcodec', 'avutil', 'swscale' ]
incdir = [ path_join(ffmpegpath, 'include'), "/usr/include/ffmpeg" , "./include" ] 

if (with_numpy):
  incdir = incdir + list(nd.get_numpy_include_dirs())
libinc = [ path_join(ffmpegpath, 'lib') ]

if platform in [ 'win32', 'win64' ] :
    libs = static_resolver(libs)
    libinc += [ r'/mingw/lib' ] # it seems some people require this

if with_numpy:
        ext_modules=[ Extension('pyffmpeg', [ 'pyffmpeg.pyx' ],
                       include_dirs = incdir,
                       library_dirs = libinc,
                       libraries = libs,
                       extra_compile_args=extra_compiler_args),
                      Extension('audioqueue', [ 'audioqueue.pyx' ],
                       include_dirs = incdir,
                       library_dirs = libinc,
                       libraries = libs,
                       extra_compile_args=extra_compiler_args),
                      Extension('pyffmpeg_numpybindings', [ 'pyffmpeg_numpybindings.pyx' ],
                       include_dirs = incdir,
                       library_dirs = libinc,
                       libraries = libs,
                       extra_compile_args=extra_compiler_args)
                     ]
else:
        ext_modules=[ Extension('pyffmpeg', [ 'pyffmpeg.pyx' ],
                       include_dirs = incdir, 
                       library_dirs = libinc,
                       libraries = libs,
                       extra_compile_args=extra_compiler_args)
                    ]


setup(
    name = 'pyffmpeg',
    cmdclass = {'build_ext': build_ext},
    version = "2.1beta",
    ext_modules = ext_modules
)
