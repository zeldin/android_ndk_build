import os
import build_support
import multiprocessing
import subprocess

ORIG_ENV = dict(os.environ)

def main():
    arg_parser = build_support.ArgParser()
    arg_parser.add_argument('--installed-ndk-clang', help='Path to an installed NDK clang', type=os.path.realpath)
    arg_parser.add_argument('--prebuilt-clang-path', help='Path to an installed system clang', type=os.path.realpath, default='/usr/bin')
    args = arg_parser.parse_args()
    env = dict(ORIG_ENV)
    env['FORCE_BUILD_LLVM_COMPONENTS'] = 'true'
    env['SKIP_LLVM_TESTS'] = 'true'
    env['TARGET_PRODUCT'] = 'sdk'
    o = args.out_dir+'/host/'+build_support.host_to_tag(args.host)

    prebuilts_path=args.prebuilt_clang_path

    overrides = []
    overrides.append('LLVM_PREBUILTS_PATH={}'.format(prebuilts_path))

    targets = [o+'/bin/clang', o+'/bin/llvm-as', o+'/bin/llvm-link']

    jobs_arg = '-j{}'.format(multiprocessing.cpu_count())
    subprocess.check_call(
	['make', jobs_arg] + overrides + targets, env=env)
    if not os.access(o+'/lib64/clang', os.X_OK):
        os.symlink(args.installed_ndk_clang+'/lib64/clang', o+'/lib64/clang')

if __name__ == '__main__':
    main()


