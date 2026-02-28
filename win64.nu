# requires Nushell 0.90+

# absolute; use `\\` as separator; no whitespaces
let tmp_dir = 'c:\\0'
# absolute; use `/` as separator; allow whitespaces
let libsndfile_prefix = $'($tmp_dir)/i/libsndfile'
# absolute; use `/` as separator; allow whitespaces
let fluidsynth_prefix = 'C:/Program Files/fluidsynth'

$env.CC = 'clang-cl'
$env.CXX = 'clang-cl'
$env.LD = 'lld-link'

let cflags = '/D_CRT_SECURE_NO_WARNINGS /DNDEBUG /D_WIN64 /O2 /Ob2 /Oi /Ot /Gw /Gy /w -fms-extensions -fms-compatibility -Wall -O3 -march=native -mtune=native -mno-avx512f -flto -fwhole-program-vtables -fuse-ld=lld'
$env.CFLAGS = $'($cflags) /std:clatest'
$env.CXXFLAGS = $'($cflags) /EHsc /std:c++latest'
$env.LDFLAGS = '/LTCG /OPT:REF /OPT:ICF /MACHINE:X64'
$env.CMAKE_INSTALL_PARALLEL_LEVEL = ($env.NUMBER_OF_PROCESSORS? | default '1')
$env.CMAKE_BUILD_TYPE = 'Release'
$env.CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP = 'TRUE'
$env.BUILD_SHARED_LIBS = 'OFF'
$env.BUILD_TESTING = 'OFF'

def cmd-exists [name: string] {
  (which $name | length) > 0
}

def --env run-or-fail [task: closure, error_msg: string] {
  do $task
  if (($env.LAST_EXIT_CODE? | default 0) != 0) {
    print $error_msg
    exit 1
  }
}

# check command exists
if not (cmd-exists 'git') {
  print "Can't find command `git`. Did you install it?"
  exit 1
}
if not (cmd-exists $env.CC) {
  print $"Can't find command `($env.CC)`. Did you install it and run the script from VS CLI?"
  exit 1
}
if not (cmd-exists 'cmake') {
  print "Can't find command `cmake`. Did you install it?"
  exit 1
}
if not (cmd-exists 'ninja') {
  print "Can't find command `ninja`. Did you install it?"
  exit 1
}

mkdir $tmp_dir
cd $tmp_dir

let jobs = ($env.NUMBER_OF_PROCESSORS? | default '1')
let git_clone = {|url: string| ^git clone --depth 1 --recursive -j $jobs $url }

# get libsndfile src
let libsndfile_exist_mark = 'libsndfile/__exist__'
if not ('libsndfile' | path exists) {
  run-or-fail {|| do $git_clone 'https://github.com/libsndfile/libsndfile' } 'Failed to clone libsndfile.'
  '' | save --force $libsndfile_exist_mark
} else if not ($libsndfile_exist_mark | path exists) {
  print 'libsndfile is cloned but not complete.'
  exit 1
}

# get fluidsynth src
let fluidsynth_exist_mark = 'fluidsynth/__exist__'
if not ('fluidsynth' | path exists) {
  run-or-fail {|| do $git_clone 'https://github.com/FluidSynth/fluidsynth' } 'Failed to clone fluidsynth.'
  '' | save --force $fluidsynth_exist_mark
} else if not ($fluidsynth_exist_mark | path exists) {
  print 'fluidsynth is cloned but not complete.'
  exit 1
}

# build libsndfile
let libsndfile_build_dir = '../b/libsndfile'
cd 'libsndfile'
run-or-fail {|| ^cmake -G Ninja -B $libsndfile_build_dir } 'CMake configure bootstrap failed for libsndfile.'
run-or-fail {
  ||
  ^cmake -B $libsndfile_build_dir
    $'-DCMAKE_BUILD_TYPE=($env.CMAKE_BUILD_TYPE)'
    '-DBUILD_SHARED_LIBS=OFF'
    '-DBUILD_EXAMPLES=OFF'
    '-DBUILD_PROGRAMS=OFF'
    '-DBUILD_TESTING=OFF'
    $'-DCMAKE_INSTALL_PREFIX=($libsndfile_prefix)'
    '-DENABLE_CPACK=OFF'
    '-DENABLE_EXTERNAL_LIBS=OFF'
    '-DENABLE_MPEG=OFF'
    '-DINSTALL_MANPAGES=OFF'
} 'CMake configure failed for libsndfile.'
cd $libsndfile_build_dir
run-or-fail {|| ^ninja -j $jobs } 'Found errors in libsndfile build.'
run-or-fail {|| ^cmake --install . --strip } 'Found errors in libsndfile install.'
cd $tmp_dir

# build fluidsynth
let fluidsynth_build_dir = '../b/fluidsynth'
cd 'fluidsynth'
run-or-fail {|| ^cmake -G Ninja -B $fluidsynth_build_dir } 'CMake configure bootstrap failed for FluidSynth.'
run-or-fail {
  ||
  ^cmake -B $fluidsynth_build_dir
    $'-DCMAKE_BUILD_TYPE=($env.CMAKE_BUILD_TYPE)'
    '-DBUILD_SHARED_LIBS=OFF'
    '-Denable-dbus=OFF'
    '-Denable-dsound=OFF'
    '-Denable-jack=OFF'
    '-Denable-ladspa=OFF'
    '-Denable-libinstpatch=OFF'
    '-Denable-midishare=OFF'
    '-Denable-network=OFF'
    '-Denable-openmp=OFF'
    '-Denable-pulseaudio=OFF'
    '-Denable-readline=OFF'
    '-Denable-sdl3=OFF'
    '-Denable-waveout=OFF'
    '-Dosal=cpp11'
    '-DDEFAULT_SOUNDFONT=C:\\Windows\\System32\\drivers\\gm.dls'
    $'-DCMAKE_INSTALL_PREFIX=($fluidsynth_prefix)'
} 'CMake configure failed for FluidSynth.'
run-or-fail {|| ^cmake -B $fluidsynth_build_dir $'-DSndFile_DIR=($libsndfile_prefix)/cmake' } 'Failed to configure SndFile_DIR for FluidSynth.'
cd $fluidsynth_build_dir
run-or-fail {|| ^ninja -j $jobs } 'Found errors in FluidSynth build.'
run-or-fail {|| ^cmake --install . --strip } 'Found errors in FluidSynth install.'
cd $tmp_dir

let dll_glob = $'($fluidsynth_prefix)/bin/*.dll'
if ((glob $dll_glob | length) > 0) {
  rm --force ... (glob $dll_glob)
}

# check
run-or-fail {|| ^dumpbin /dependents $'($fluidsynth_prefix)/bin/fluidsynth.exe' } 'Dependency check failed.'

print 'Everything is OK!'

hide-env CFLAGS
hide-env CXXFLAGS
hide-env LDFLAGS
