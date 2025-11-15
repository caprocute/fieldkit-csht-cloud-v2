use std::env;

fn main() {
    setup_x86_64_android_workaround();
}

/// Adds a temporary workaround for an issue with the Rust compiler and Android
/// in x86_64 devices: https://github.com/rust-lang/rust/issues/109717.
/// The workaround comes from: https://github.com/mozilla/application-services/pull/5442
fn setup_x86_64_android_workaround() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").expect("CARGO_CFG_TARGET_OS not set");
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").expect("CARGO_CFG_TARGET_ARCH not set");
    if target_arch == "x86_64" && target_os == "android" {
        let build_os = match env::consts::OS {
            "linux" => "linux",
            "macos" => "darwin",
            "windows" => "windows",
            _ => panic!(
                "Unsupported OS. You must use either Linux, MacOS or Windows to build the crate."
            ),
        };
        if let Some(link_path) = get_clang_path(build_os) {
            println!("cargo:rustc-link-search={link_path}");
            println!("cargo:rustc-link-lib=static=clang_rt.builtins-x86_64-android");
        }
    }
}

fn get_clang_path(build_os: &str) -> Option<String> {
    let Ok(android_ndk_home) = env::var("ANDROID_NDK_HOME") else {
        println!(
            "cargo:warning=ANDROID_NDK_HOME undefined (__extenddftf2 symbol error may occur)."
        );
        return None;
    };

    match std::fs::read_dir(format!(
        "{android_ndk_home}/toolchains/llvm/prebuilt/{build_os}-x86_64/lib64/clang/"
    )) {
        Ok(clangs) => {
            for clang in clangs.into_iter().flatten().map(|e| e.path()) {
                let clang_str = clang.to_string_lossy();
                let linux_x86_64_lib_dir = format!("{clang_str}/lib/linux/");
                return Some(format!("{linux_x86_64_lib_dir}"));
            }

            None
        }
        Err(e) => {
            println!("cargo:warning=No clang versions found ({:?}).", e);
            None
        }
    }
}
