@echo off

rem absolute; use `\` as seperator; no whitespaces
set __tmp_dir__=c:\0
rem absolute; use `/` as seperator; allow whitespaces
set __libsndfile_prefix__=%__tmp_dir__%/i/libsndfile
rem absolute; use `/` as seperator; allow whitespaces
set __fluidsynth_prefix__=C:/Program Files/fluidsynth

set CC=clang-cl
set CXX=clang-cl
set LD=lld-link
set __cflags__=/D_CRT_SECURE_NO_WARNINGS /DNDEBUG /D_WIN64 /O2 /Ob2 /Oi /Ot /Gw /Gy /w -fms-extensions -fms-compatibility -Wall -O3 -march=native -flto -fwhole-program-vtables -fuse-ld=lld
set CFLAGS=%__cflags__% /std:clatest
set CXXFLAGS=%__cflags__% /EHsc /std:c++latest
set LDFLAGS=/LTCG /OPT:REF /OPT:ICF /MACHINE:X64
set CMAKE_INSTALL_PARALLEL_LEVEL=%NUMBER_OF_PROCESSORS%
set CMAKE_BUILD_TYPE=Release
set CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP=TRUE
set BUILD_SHARED_LIBS=OFF
set BUILD_TESTING=OFF

rem check command exists
where git > nul 2> nul
if not "%errorlevel%"=="0" (
  echo Can't find command `git`. Did you install it?
  goto failure
)
where "%CC%" > nul 2> nul
if not "%errorlevel%"=="0" (
  echo Can't find command `%CC%`. Did you install it and run the script from VS CLI?
  goto failure
)
where cmake > nul 2> nul
if not "%errorlevel%"=="0" (
  echo Can't find command `cmake`. Did you install it?
  goto failure
)
where ninja > nul 2> nul
if not "%errorlevel%"=="0" (
  echo Can't find command `ninja`. Did you install it?
)

set __go_tmp__=cd /d "%__tmp_dir__%"
set __git_clone__=git clone --depth 1 --recursive -j %NUMBER_OF_PROCESSORS%
set __cmake_install__=ninja -j %NUMBER_OF_PROCESSORS% ^&^& cmake --install . --strip
md "%__tmp_dir__%" > nul 2> nul
%__go_tmp__%

rem get libsndfile src
set __libsndfile_exist_mark__=libsndfile\__exist__
if not exist "libsndfile" (
  %__git_clone__% "https://github.com/libsndfile/libsndfile"
  if "%errorlevel%"=="0" (
    echo. > "%__libsndfile_exist_mark__%"
  )
) else (
  if not exist "%__libsndfile_exist_mark__%" (
    echo libsndfile is cloned but not complete.
    goto failure
  )
)

rem get fluidsynth src
set __fluidsynth_exist_mark__=fluidsynth\__exist__
if not exist "fluidsynth" (
  %__git_clone__% "https://github.com/FluidSynth/fluidsynth"
  if "%errorlevel%"=="0" (
    echo. > "%__fluidsynth_exist_mark__%"
  )
) else (
  if not exist "%__fluidsynth_exist_mark__%" (
    echo fluidsynth is cloned but not complete.
    goto failure
  )
)

: build
set __libsndfile_b__=..\b\libsndfile
cd /d libsndfile
cmake -G Ninja -B "%__libsndfile_b__%"
cmake -B "%__libsndfile_b__%" -DCMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE% -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_PROGRAMS=OFF -DBUILD_TESTING=OFF "-DCMAKE_INSTALL_PREFIX=%__libsndfile_prefix__%" -DENABLE_CPACK=OFF -DENABLE_EXTERNAL_LIBS=OFF -DENABLE_MPEG=OFF -DINSTALL_MANPAGES=OFF
cd /d "%__libsndfile_b__%"
%__cmake_install__%
if not "%errorlevel%"=="0" (
  echo Found errors in libsndfile.
  goto failure
)
%__go_tmp__%

set __fluidsynth_b__=..\b\fluidsynth
cd /d fluidsynth
cmake -G Ninja -B "%__fluidsynth_b__%"
cmake -B "%__fluidsynth_b__%" -DCMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE% -DBUILD_SHARED_LIBS=OFF -Denable-dbus=OFF -Denable-dsound=OFF -Denable-jack=OFF -Denable-ladspa=OFF -Denable-libinstpatch=OFF -Denable-midishare=OFF -Denable-network=OFF -Denable-openmp=OFF -Denable-pulseaudio=OFF -Denable-readline=OFF -Denable-sdl3=OFF -Denable-waveout=OFF -Dosal=cpp11 "-DDEFAULT_SOUNDFONT=C:\\Windows\\System32\\drivers\\gm.dls" "-DCMAKE_INSTALL_PREFIX=%__fluidsynth_prefix__%"
cmake -B "%__fluidsynth_b__%" "-DSndFile_DIR=%__libsndfile_prefix__%/cmake"
cd /d "%__fluidsynth_b__%"
%__cmake_install__%
if not "%errorlevel%"=="0" (
  echo Found errors in FluidSynth.
  goto failure
)
%__go_tmp__%
del "%__fluidsynth_prefix__%\bin\*.dll"

rem check
dumpbin /dependents "%__fluidsynth_prefix__%\bin\fluidsynth.exe"

goto success

: failure
echo Something went wrong!
goto cleanup

: success
echo Everything is OK!

: cleanup
set CFLAGS=
set CXXFLAGS=
set LDFLAGS=
pause
