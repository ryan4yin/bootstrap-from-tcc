{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, intermediate-musl, gnugcc10
, linux-headers, cmake, python}:

let
  source-tarball-llvm = fetchurl {
    # local = /downloads/llvm-project-17.0.1.src.tar.xz;
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.1/llvm-project-17.0.1.src.tar.xz";
    sha256 = "b0e42aafc01ece2ca2b42e3526f54bebc4b1f1dc8de6e34f46a0446a13e882b9";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a9-intermediate-clang";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/wrappers"
      "${static-binutils}/bin"
      "${gnugcc10}/bin"
      "${cmake}/bin"
      "${python}/bin"
    ];
    script = ''
        mkdir build-dir; cd build-dir
        export SHELL=${stage1.protobusybox}/bin/ash
        # llvm cmake configuration should pick up ccache automatically from PATH
        export PATH="$PATH:/ccache/bin"
        command -v ccache && USE_CCACHE=YES || USE_CCACHE=NO
      # prepare future sysroot:
        SYSROOT=$out/sysroot
        mkdir -p $SYSROOT/lib $SYSROOT/include
        ln -s ${intermediate-musl}/lib/* $SYSROOT/lib/
        ln -s ${intermediate-musl}/include/* $SYSROOT/include/
      # unpack:
        unpack ${source-tarball-llvm}
      # fixup:
        sed -i "s|COMMAND sh|COMMAND ${stage1.protobusybox}/bin/ash|" \
          llvm/cmake/modules/GetHostTriple.cmake clang/CMakeLists.txt
        echo 'echo x86_64-unknown-linux-musl' > llvm/cmake/config.guess
        LOADER=${intermediate-musl}/lib/libc.so
        sed -i "s|/lib/ld-musl-\" + ArchName + \".so.1|$LOADER|" \
          clang/lib/Driver/ToolChains/Linux.cpp
        BEGINEND='const bool HasCRTBeginEndFiles'
        sed -i "s|$BEGINEND =|$BEGINEND = false; ''${BEGINEND}_unused =|" \
          clang/lib/Driver/ToolChains/Gnu.cpp
        REL_ORIGIN='_install_rpath \"\$ORIGIN/../lib''${LLVM_LIBDIR_SUFFIX}\"'
        sed -i "s|_install_rpath \"\\\\\$ORIGIN/..|_install_rpath \"$out|" \
          llvm/cmake/modules/AddLLVM.cmake
        sed -i 's|numShards = 32;|numShards = 1;|' lld/*/SyntheticSections.*
        sed -i 's|numShards = 256;|numShards = 1;|' lld/*/ICF.cpp
        sed -i 's|__FILE__|"__FILE__"|' compiler-rt/lib/builtins/int_util.h
      # figure out includes:
        C_INCLUDES="$SYSROOT/include"
        C_INCLUDES="$C_INCLUDES:${linux-headers}/include"
        EXTRA_INCL="$(pwd)/extra_includes"
        mkdir -p $EXTRA_INCL
        cp clang/lib/Headers/*intrin*.h $EXTRA_INCL/
        cp clang/lib/Headers/mm_malloc.h $EXTRA_INCL/
        [ -e $EXTRA_INCL/immintrin.h ]
      # configure:
        export LD_LIBRARY_PATH=${gnugcc10}/lib
        BOTH_STAGES_OPTS=""
        add_opt() {
          BOTH_STAGES_OPTS="$BOTH_STAGES_OPTS -D$1 -DBOOTSTRAP_$1"
        }
        add_opt CMAKE_BUILD_TYPE=MinSizeRel
        add_opt LLVM_OPTIMIZED_TABLEGEN=YES
        add_opt LLVM_CCACHE_BUILD=$USE_CCACHE
        add_opt DEFAULT_SYSROOT=$SYSROOT
        add_opt C_INCLUDE_DIRS=$C_INCLUDES
        add_opt CMAKE_INSTALL_PREFIX=$out
        add_opt LLVM_INSTALL_BINUTILS_SYMLINKS=YES
        add_opt LLVM_INSTALL_CCTOOLS_SYMLINKS=YES
        add_opt CMAKE_INSTALL_DO_STRIP=YES
        add_opt LLVM_ENABLE_PER_TARGET_RUNTIME_DIR=YES
        add_opt LLVM_TARGET_ARCH=X86
        add_opt LLVM_TARGETS_TO_BUILD=Native
        add_opt LLVM_BUILTIN_TARGETS=x86_64-unknown-linux-musl
        add_opt LLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl
        add_opt LLVM_HOST_TRIPLE=x86_64-unknown-linux-musl
        add_opt COMPILER_RT_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl
        add_opt LLVM_APPEND_VC_REV=NO
        add_opt LLVM_INCLUDE_TESTS=NO
        add_opt LLVM_INCLUDE_EXAMPLES=NO
        add_opt LLVM_INCLUDE_BENCHMARKS=NO
        add_opt LLVM_ENABLE_BACKTRACES=NO
        add_opt LLVM_ENABLE_EH=YES
        add_opt LLVM_ENABLE_RTTI=YES
        add_opt CLANG_ENABLE_ARCMT=NO
        add_opt CLANG_ENABLE_STATIC_ANALYZER=NO
        add_opt COMPILER_RT_BUILD_SANITIZERS=NO
        add_opt COMPILER_RT_BUILD_XRAY=NO
        add_opt COMPILER_RT_BUILD_LIBFUZZER=NO
        add_opt COMPILER_RT_BUILD_PROFILE=NO
        add_opt COMPILER_RT_BUILD_MEMPROF=NO
        add_opt COMPILER_RT_BUILD_ORC=NO
        add_opt COMPILER_RT_USE_BUILTINS_LIBRARY=YES
        add_opt CLANG_DEFAULT_CXX_STDLIB=libc++
        add_opt CLANG_DEFAULT_LINKER=lld
        add_opt CLANG_DEFAULT_RTLIB=compiler-rt
        add_opt LIBCXX_HAS_MUSL_LIBC=YES
        add_opt LIBCXX_USE_COMPILER_RT=YES
        add_opt LIBCXX_INCLUDE_BENCHMARKS=NO
        add_opt LIBCXX_CXX_ABI=libcxxabi
        add_opt LIBCXXABI_USE_COMPILER_RT=YES
        add_opt LIBCXXABI_USE_LLVM_UNWINDER=YES
        add_opt LLVM_INSTALL_TOOLCHAIN_ONLY=YES
        add_opt LIBUNWIND_USE_COMPILER_RT=YES
        add_opt LLVM_ENABLE_THREADS=NO
        cmake -S llvm -B build -G 'Unix Makefiles' \
          -DLLVM_ENABLE_PROJECTS='clang;lld' \
          -DLLVM_ENABLE_RUNTIMES='compiler-rt;libcxx;libcxxabi;libunwind' \
          -DGCC_INSTALL_PREFIX=${gnugcc10} \
          "-DBOOTSTRAP_CMAKE_C_FLAGS=-isystem $EXTRA_INCL" \
          "-DBOOTSTRAP_CMAKE_CXX_FLAGS=-isystem $EXTRA_INCL" \
          -DCLANG_ENABLE_BOOTSTRAP=YES $BOTH_STAGES_OPTS
      # build (stage1):
        make -C build -j $NPROC clang lld runtimes
      # build/install (stage2):
        NEW_LIB_DIR="$(pwd)/build/lib/x86_64-unknown-linux-musl"
        export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$NEW_LIB_DIR"
        make -C build -j $NPROC stage2 stage2-install
        ln -s $out/lib/x86_64-unknown-linux-musl/* $out/lib/
        mkdir -p $out/bin/generic-names
        ln -s $out/bin/clang $out/bin/generic-names/cc
        ln -s $out/bin/clang++ $out/bin/generic-names/c++
        ln -s $out/bin/clang-cpp $out/bin/generic-names/cpp
      # mix new stuff into sysroot
        ln -s $out/lib/* $out/sysroot/lib/
      # check for build path leaks:
        ( ! grep -RF $(pwd) $out )
    '';
  }
