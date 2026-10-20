//! Lowrail CLI. See docs/PLAN.md for the pipeline and docs/FORMATS.md for
//! the files each step reads and writes.

mod build;
mod facts;
mod lower;
mod mcp;
mod observe;
mod passes;
mod types;
mod verify;

use std::process::ExitCode;

const USAGE: &str = "usage: lowrail <command> [args]
  parse FILE...        check that files parse with Prism
  facts APP            boot APP, write APP/.lowrail/facts.json, print a summary
  build APP            lower APP using its facts, write ISeqs + manifest
  types APP [--rbs DIR] derive types from boot facts, optionally write RBS
  mcp APP              serve read-only type/fact tools over stdio
  verify APP           run APP's tests with LOWRAIL=0 and 1, compare outcomes
  observe APP          run APP's tests with the recorder, write .lowrail/observed.json";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let result = match args.split_first() {
        Some((cmd, rest)) => match cmd.as_str() {
            "parse" => parse(rest),
            "facts" => facts::cli(rest),
            "build" => build::cli(rest),
            "types" => types::cli(rest),
            "mcp" => mcp::cli(rest),
            "verify" => verify::cli(rest),
            "observe" => observe::cli(rest),
            _ => Err(USAGE.to_string()),
        },
        None => Err(USAGE.to_string()),
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(msg) => {
            eprintln!("{msg}");
            ExitCode::FAILURE
        }
    }
}

fn parse(files: &[String]) -> Result<(), String> {
    let mut failed = 0;
    for path in files {
        let source = std::fs::read(path).map_err(|e| format!("{path}: {e}"))?;
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
    if failed == 0 { Ok(()) } else { Err("parse errors".into()) }
}
