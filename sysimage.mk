SRCDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILDDIR := .
JULIAHOME := $(SRCDIR)
include $(JULIAHOME)/Make.inc
include $(JULIAHOME)/stdlib/stdlib.mk

default: sysimg-$(JULIA_BUILD_MODE) # contains either "debug" or "release"
all: sysimg-release sysimg-debug
basecompiler-ji: $(build_private_libdir)/basecompiler.ji
sysimg-ji: $(build_private_libdir)/sysbase.ji
sysimg-bc: $(build_private_libdir)/sys-bc.a
sysimg-release: $(build_private_libdir)/sys.$(SHLIB_EXT)
sysimg-debug: $(build_private_libdir)/sys-debug.$(SHLIB_EXT)
sysbase-release: $(build_private_libdir)/sysbase.$(SHLIB_EXT)
sysbase-debug: $(build_private_libdir)/sysbase-debug.$(SHLIB_EXT)

VERSDIR := v$(shell cut -d. -f1-2 < $(JULIAHOME)/VERSION)

$(build_private_libdir)/%.$(SHLIB_EXT): $(build_private_libdir)/%-o.a
	@$(call PRINT_LINK, $(CXX) $(LDFLAGS) -shared $(fPIC) -L$(build_private_libdir) -L$(build_libdir) -L$(build_shlibdir) -o $@ \
		$(WHOLE_ARCHIVE) $< $(NO_WHOLE_ARCHIVE) \
		$(if $(findstring -debug,$(notdir $@)),-ljulia-internal-debug -ljulia-debug,-ljulia-internal -ljulia) \
		$$([ $(OS) = WINNT ] && echo '' $(LIBM) -lssp -Wl,--disable-auto-import -Wl,--disable-runtime-pseudo-reloc))
	@$(INSTALL_NAME_CMD)$(notdir $@) $@
	@$(DSYMUTIL) $@

COMPILER_SRCS := $(addprefix $(JULIAHOME)/, \
		base/Base_compiler.jl \
		base/boot.jl \
		base/docs/core.jl \
		base/abstractarray.jl \
		base/abstractdict.jl \
		base/abstractset.jl \
		base/iddict.jl \
		base/idset.jl \
		base/anyall.jl \
		base/array.jl \
		base/baseext.jl \
		base/bitarray.jl \
		base/bitset.jl \
		base/bool.jl \
		base/c.jl \
		base/checked.jl \
		base/cmem.jl \
		base/coreio.jl \
		base/coreir.jl \
		base/ctypes.jl \
		base/error.jl \
		base/essentials.jl \
		base/expr.jl \
		base/exports.jl \
		base/flfrontend.jl \
		base/float.jl \
		base/gcutils.jl \
		base/generator.jl \
		base/genericmemory.jl \
		base/int.jl \
		base/indices.jl \
		base/iterators.jl \
		base/invalidation.jl \
		base/module.jl \
		base/namedtuple.jl \
		base/ntuple.jl \
		base/number.jl \
		base/operators.jl \
		base/options.jl \
		base/ordering.jl \
		base/pair.jl \
		base/pointer.jl \
		base/promotion.jl \
		base/public.jl \
		base/range.jl \
		base/refvalue.jl \
		base/rounding.jl \
		base/runtime_internals.jl \
		base/strings/lazy.jl \
		base/traits.jl \
		base/tuple.jl)
COMPILER_SRCS += $(shell find $(JULIAHOME)/Compiler/src -name \*.jl -and -not -name verifytrim.jl -and -not -name show.jl)
# sort these to remove duplicates
BASE_SRCS := $(sort $(shell find $(JULIAHOME)/base -name \*.jl -and -not -name sysimg.jl) \
                    $(shell find $(BUILDROOT)/base -name \*.jl  -and -not -name sysimg.jl)) \
             $(JULIAHOME)/Compiler/src/ssair/show.jl \
             $(JULIAHOME)/Compiler/src/verifytrim.jl
STDLIB_SRCS := $(JULIAHOME)/base/sysimg.jl $(SYSIMG_STDLIBS_SRCS)
RELBUILDROOT := $(call rel_path,$(JULIAHOME)/base,$(BUILDROOT)/base)/ # <-- make sure this always has a trailing slash
RELDATADIR := $(call rel_path,$(JULIAHOME)/base,$(build_datarootdir))/ # <-- make sure this always has a trailing slash

$(build_private_libdir)/basecompiler.ji: $(COMPILER_SRCS)
	@$(call PRINT_JULIA, cd $(JULIAHOME)/base && \
	JULIA_NUM_THREADS=1 $(call spawn,$(JULIA_EXECUTABLE)) $(HEAPLIM) --output-ji $(call cygpath_w,$@).tmp \
		--startup-file=no --warn-overwrite=yes --depwarn=error -g$(BOOTSTRAP_DEBUG_LEVEL) -O1 Base_compiler.jl --buildroot $(RELBUILDROOT) --dataroot $(RELDATADIR))
	@mv $@.tmp $@

define base_builder
$$(build_private_libdir)/basecompiler$1-o.a $$(build_private_libdir)/basecompiler$1-bc.a : $$(build_private_libdir)/basecompiler$1-%.a : $(COMPILER_SRCS)
	@$$(call PRINT_JULIA, cd $$(JULIAHOME)/base && \
	WINEPATH="$$(call cygpath_w,$$(build_bindir));$$$$WINEPATH" \
	JULIA_NUM_THREADS=1 \
		$$(call spawn, $3) $2 -C "$$(JULIA_CPU_TARGET)" $$(HEAPLIM) --output-$$* $$(call cygpath_w,$$@).tmp \
		--startup-file=no --warn-overwrite=yes --depwarn=error -g$$(BOOTSTRAP_DEBUG_LEVEL) Base_compiler.jl --buildroot $$(RELBUILDROOT) --dataroot $$(RELDATADIR))
	@mv $$@.tmp $$@
$$(build_private_libdir)/sysbase$1.ji: $$(build_private_libdir)/basecompiler$1.$$(SHLIB_EXT) $$(JULIAHOME)/VERSION $$(BASE_SRCS) $$(STDLIB_SRCS)
	@$$(call PRINT_JULIA, cd $$(JULIAHOME)/base && \
	if ! JULIA_BINDIR=$$(call cygpath_w,$$(build_bindir)) \
	     WINEPATH="$$(call cygpath_w,$$(build_bindir));$$$$WINEPATH" \
		 JULIA_NUM_THREADS=1 \
			$$(call spawn, $$(JULIA_EXECUTABLE)) -g1 $2 -C "$$(JULIA_CPU_TARGET)" $$(HEAPLIM) --output-ji $$(call cygpath_w,$$@).tmp $$(JULIA_SYSIMG_BUILD_FLAGS) \
			--startup-file=no --warn-overwrite=yes --depwarn=error --sysimage $$(call cygpath_w,$$<) sysimg.jl --buildroot $$(RELBUILDROOT) --dataroot $$(RELDATADIR); then \
		echo '*** This error might be fixed by running `make clean`. If the error persists$$(COMMA) try `make cleanall`. ***'; \
		false; \
	fi )
	@mv $$@.tmp $$@
.SECONDARY: $$(build_private_libdir)/basecompiler$1-o.a $$(build_private_libdir)/basecompiler$1-bc.a $$(build_private_libdir)/sysbase$1.ji # request Make to keep these files around
endef

define sysimg_builder
$$(build_private_libdir)/sysbase$1-o.a $$(build_private_libdir)/sysbase$1-bc.a : $$(build_private_libdir)/sysbase$1-%.a : $$(build_private_libdir)/basecompiler$1.$$(SHLIB_EXT) $$(JULIAHOME)/VERSION $$(BASE_SRCS) $$(STDLIB_SRCS)
	@$$(call PRINT_JULIA, cd $$(JULIAHOME)/base && \
	if ! JULIA_BINDIR=$$(call cygpath_w,$$(build_bindir)) \
	     WINEPATH="$$(call cygpath_w,$$(build_bindir));$$$$WINEPATH" \
		 JULIA_NUM_THREADS=1 \
			$$(call spawn, $$(JULIA_EXECUTABLE)) -g1 $2 -C "$$(JULIA_CPU_TARGET)" $$(HEAPLIM) --output-$$* $$(call cygpath_w,$$@).tmp $$(JULIA_SYSIMG_BUILD_FLAGS) \
			--startup-file=no --warn-overwrite=yes --depwarn=error --sysimage $$(call cygpath_w,$$<) sysimg.jl --buildroot $$(RELBUILDROOT) --dataroot $$(RELDATADIR); then \
		echo '*** This error might be fixed by running `make clean`. If the error persists$$(COMMA) try `make cleanall`. ***'; \
		false; \
	fi )
	@mv $$@.tmp $$@
build_sysbase_$1 := $$(or $$(CROSS_BOOTSTRAP_SYSBASE),$$(build_private_libdir)/sysbase$1.$$(SHLIB_EXT))
$$(build_private_libdir)/sys$1-o.a $$(build_private_libdir)/sys$1-bc.a : $$(build_private_libdir)/sys$1-%.a : $$(build_sysbase_$1) $$(JULIAHOME)/contrib/generate_precompile.jl
	@$$(call PRINT_JULIA, cd $$(JULIAHOME)/base && \
	if ! JULIA_BINDIR=$$(call cygpath_w,$(build_bindir)) \
		 WINEPATH="$$(call cygpath_w,$$(build_bindir));$$$$WINEPATH" \
		 JULIA_LOAD_PATH='@stdlib' \
		 JULIA_PROJECT= \
		 JULIA_DEPOT_PATH=':' \
		 JULIA_NUM_THREADS=1 \
			$$(call spawn, $3) $2 -C "$$(JULIA_CPU_TARGET)" $$(HEAPLIM) --output-$$* $$(call cygpath_w,$$@).tmp $$(JULIA_SYSIMG_BUILD_FLAGS) \
			$(bootstrap_julia_flags) \
			--startup-file=no --warn-overwrite=yes --depwarn=error --sysimage $$(call cygpath_w,$$<) $$(call cygpath_w,$$(JULIAHOME)/contrib/generate_precompile.jl) $(JULIA_PRECOMPILE); then \
		echo '*** This error is usually fixed by running `make clean`. If the error persists$$(COMMA) try `make cleanall`. ***'; \
		false; \
	fi )
	@mv $$@.tmp $$@
.SECONDARY: $$(build_private_libdir)/sys$1-o.a $(build_private_libdir)/sys$1-bc.a # request Make to keep these files around
.SECONDARY: $$(build_private_libdir)/sysbase$1-o.a $(build_private_libdir)/sysbase$1-bc.a # request Make to keep these files around
endef
$(eval $(call base_builder,,-O1,$(JULIA_EXECUTABLE_release)))
$(eval $(call base_builder,-debug,-O0,$(JULIA_EXECUTABLE_debug)))
$(eval $(call sysimg_builder,,-O3,$(JULIA_EXECUTABLE_release)))
$(eval $(call sysimg_builder,-debug,-O0,$(JULIA_EXECUTABLE_debug)))
