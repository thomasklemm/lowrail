// Reduced model of gen_iseq() holding a &mut IseqPayload while gen_entry_point() ->
// JITFrame::new_iseq() -> iseq_may_write_block_code() reads the cache for the same ISEQ.
// Run: cargo +nightly miri run -- old|new   (MIRIFLAGS=-Zmiri-tree-borrows for Tree Borrows)
use std::ffi::c_void;
use std::ptr::null_mut;

struct IseqPayload {
    versions: Vec<u32>,
    num_exits_until_invalidate: u32,
    may_write_block_code: Option<bool>,
}

// Stands in for iseq->aux.zjit_payload, owned by C.
static mut JIT_PAYLOAD: *mut c_void = null_mut();

fn get_iseq_payload_ptr() -> *mut IseqPayload { unsafe { JIT_PAYLOAD as *mut IseqPayload } }
fn payload_ptr_as_mut(p: *mut IseqPayload) -> &'static mut IseqPayload { unsafe { p.as_mut() }.unwrap() }
fn get_or_create_iseq_payload() -> &'static mut IseqPayload {
    unsafe {
        if JIT_PAYLOAD.is_null() {
            let p = Box::into_raw(Box::new(IseqPayload { versions: vec![], num_exits_until_invalidate: 5, may_write_block_code: None }));
            JIT_PAYLOAD = p as *mut c_void;
        }
    }
    payload_ptr_as_mut(get_iseq_payload_ptr())
}

fn scan() -> bool { true }

// 35d9707959
fn cached_old() -> bool {
    let payload = get_iseq_payload_ptr();
    if payload.is_null() { return scan(); }
    *payload_ptr_as_mut(payload).may_write_block_code.get_or_insert_with(scan)
}

// 25e91f0d07 (-4): borrow only the field through the raw pointer
fn cached_new() -> bool {
    let payload = get_iseq_payload_ptr();
    if payload.is_null() { return scan(); }
    let cache = unsafe { &mut *std::ptr::addr_of_mut!((*payload).may_write_block_code) };
    *cache.get_or_insert_with(scan)
}

fn gen_iseq_body(new: bool) -> u32 {
    // gen_entry_point, then a side exit: two JITFrames for the same ISEQ
    let a = if new { cached_new() } else { cached_old() };
    let b = if new { cached_new() } else { cached_old() };
    (a && b) as u32
}

fn gen_iseq(new: bool) {
    let payload = get_or_create_iseq_payload();
    let _ = payload.versions.last();
    let v = gen_iseq_body(new);
    payload.num_exits_until_invalidate = 5;
    payload.versions.push(v);
}

fn main() {
    let new = std::env::args().nth(1).as_deref() == Some("new");
    gen_iseq(new);
    gen_iseq(new);
    assert_eq!(Some(true), payload_ptr_as_mut(get_iseq_payload_ptr()).may_write_block_code);
    unsafe { drop(Box::from_raw(get_iseq_payload_ptr())); }
    println!("ok {}", if new { "new" } else { "old" });
}
