# typed: strict
# frozen_string_literal: true

module UnpackStrategy
  # Strategy for unpacking directories.
  class Directory
    include UnpackStrategy

    sig { override.returns(T::Array[String]) }
    def self.extensions
      []
    end

    sig { override.params(path: Pathname).returns(T::Boolean) }
    def self.can_extract?(path)
      path.directory?
    end

    sig {
      params(
        path:         T.any(String, Pathname),
        ref_type:     T.nilable(Symbol),
        ref:          T.nilable(String),
        merge_xattrs: T::Boolean,
        move:         T::Boolean,
      ).void
    }
    def initialize(path, ref_type: nil, ref: nil, merge_xattrs: false, move: false)
      super(path, ref_type:, ref:, merge_xattrs:)
      @move = move
    end

    private

    sig { override.params(unpack_dir: Pathname, basename: Pathname, verbose: T::Boolean).void }
    def extract_to_dir(unpack_dir, basename:, verbose:)
      move_to_dir(unpack_dir, verbose:) if @move

      path.each_child do |child|
        system_command! "cp",
                        args:    ["-pR", (child.directory? && !child.symlink?) ? "#{child}/." : child,
                                  unpack_dir/child.basename],
                        verbose:
      end
    end

    # Move files and non-conflicting directories from `path` to `unpack_dir`
    #
    # @raise [RuntimeError] if moving a non-directory over an existing directory or vice versa
    sig { params(unpack_dir: Pathname, verbose: T::Boolean).void }
    def move_to_dir(unpack_dir, verbose:)
      path.find(ignore_error: false) do |src|
        next if src == path

        dst = unpack_dir/src.relative_path_from(path)
        if dst.exist?
          dst_real_dir = dst.directory? && !dst.symlink?
          src_real_dir = src.directory? && !src.symlink?
          # Avoid trying to move a non-directory over an existing directory or vice versa.
          # This is similar to `cp` which fails with errors like 'cp: <dst>: Is a directory'.
          # However, unlike `cp`, this will fail early rather than at then end.
          raise "Cannot move directory #{src} to non-directory #{dst}" if src_real_dir && !dst_real_dir
          raise "Cannot move non-directory #{src} to directory #{dst}" if !src_real_dir && dst_real_dir
          # Defer writing over existing directories. Handle this later on to copy attributes
          next if dst_real_dir

          FileUtils.rm(dst, verbose:)
        end

        FileUtils.mv(src, dst, verbose:)
        Find.prune
      end
    end
  end
end
