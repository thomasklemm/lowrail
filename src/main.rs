//! Lowrail CLI. Only `parse` exists so far: it checks that every given Ruby
//! file parses with Prism, as a smoke test of the toolchain.

use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.split_first() {
        Some((cmd, files)) if cmd == "parse" => parse(files),
        _ => {
            eprintln!("usage: lowrail parse FILE...\n(planned: facts, profile, build, verify, mcp, bench — see docs/PLAN.md)");
            ExitCode::from(2)
        }
    }
}

fn parse(files: &[String]) -> ExitCode {
    let mut failed = 0;
    for path in files {
        let source = match std::fs::read(path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("{path}: {e}");
                failed += 1;
                continue;
            }
        };
        let result = ruby_prism::parse(&source);
        let errors: Vec<_> = result.errors().collect();
        if !errors.is_empty() {
            failed += 1;
            for err in errors {
                eprintln!("{path}:{}: {}", err.location().start_offset(), err.message());
            }
        }
    }
    println!("{} files, {} with parse errors", files.len(), failed);
    if failed == 0 { ExitCode::SUCCESS } else { ExitCode::FAILURE }
}
