//! Lowrail CLI. See docs/PLAN.md for the pipeline and docs/FORMATS.md for
//! the files each step reads and writes.

mod bench;
mod build;
mod explain;
mod facts;
mod lower;
mod mcp;
mod observe;
mod parser;
mod passes;
mod seal;
mod types;
mod verify;

use std::process::ExitCode;

const USAGE: &str = "usage: lowrail <command> [args]
  parse --ruby-version VERSION FILE...  check files with explicit target Ruby syntax
  facts APP            boot APP, write APP/.lowrail/facts.json, print a summary
  build APP            lower APP using its facts, write ISeqs + manifest
  explain APP          explain current build units/sites, guards, refusals and recorded counters
  bench APP (--pass NAME | --passes SET --default-build DIR) [--path PATH]
                       controlled pass/request measurements; --budgets JSON for additivity
  types APP [--rbs DIR] derive types from boot facts, optionally write RBS
  types --rbs APP      export standalone RBS to stdout with per-slot evidence
  mcp APP              serve read-only type/fact tools over stdio
  verify APP           run APP's tests with LOWRAIL=0 and 1, compare outcomes
  seal-check APP       run APP's tests and report post-seal contract observations
  doctor APP           boot, baseline tests, hints; optional --seal-check / --trace-check
  observe APP          run APP's tests with the recorder, write .lowrail/observed.json";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let result = match args.split_first() {
        Some((cmd, rest)) => match cmd.as_str() {
            "parse" => parse(rest),
            "facts" => facts::cli(rest),
            "build" => build::cli(rest),
            "explain" => explain::cli(rest),
            "bench" => bench::cli(rest),
            "types" => types::cli(rest),
            "mcp" => mcp::cli(rest),
            "verify" => verify::cli(rest),
            "seal-check" => seal::cli(rest),
            "doctor" => seal::doctor(rest),
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

fn parse(args: &[String]) -> Result<(), String> {
    let [flag, version, files @ ..] = args else {
        return Err("usage: lowrail parse --ruby-version VERSION FILE... (target Ruby required)".into());
    };
    if flag != "--ruby-version" || files.is_empty() {
        return Err("usage: lowrail parse --ruby-version VERSION FILE... (target Ruby required)".into());
    }
    let parser = parser::Parser::for_runtime(version)?;
    let mut failed = 0;
    for path in files {
        let source = std::fs::read(path).map_err(|e| format!("{path}: {e}"))?;
        let result = parser.parse(&source);
        let errors: Vec<_> = result.errors().collect();
        if !errors.is_empty() {
            failed += 1;
            for err in errors {
                eprintln!("{path}:{}: {}", err.location().start(), String::from_utf8_lossy(err.message()));
            }
        }
    }
    println!("{} files, {} with parse errors", files.len(), failed);
    if failed == 0 { Ok(()) } else { Err("parse errors".into()) }
}
