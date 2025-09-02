The code is fully able to run on linux, however windows is still the recommended platform. The libraries we use for external functions (RUSTG and MILLA) require some extra dependencies.

After installing these packages, RUSTG should be able to build and function as intended. Build instructions are on the RUSTG page. We assume that if you are hosting on linux, you know what you are doing.

Once you've built RUSTG, you can build MILLA similarly, just go into the `milla/` directory and run `cargo build --release --target=i686-unknown-linux-gnu`.
