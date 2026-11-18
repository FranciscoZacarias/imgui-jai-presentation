FLAT_POOL_DEFAULT_RESERVE     :: 256 * 1024 * 1024;
FLAT_POOL_DEFAULT_COMMIT_STEP :: 64 * 1024;

Flat_Pool :: struct {
  alignment:   s32 = 8; // power of two
  commit_step: s64 = FLAT_POOL_DEFAULT_COMMIT_STEP;

  current_point:          *u8;
  memory_base:            *u8;
  first_uncommitted_page: *u8;
  address_limit:          *u8;
}

init :: (pool: *Flat_Pool, reserve := FLAT_POOL_DEFAULT_RESERVE, commit_step := FLAT_POOL_DEFAULT_COMMIT_STEP) {
  reserve = Align(reserve, PAGE_SIZE);
  pool.memory_base = VirtualAlloc(null, cast(u64) reserve, MEM_RESERVE, PAGE_READWRITE);
  if !pool.memory_base  log_os_error("VirtualAlloc MEM_RESERVE");

  pool.current_point          = pool.memory_base;
  pool.first_uncommitted_page = pool.memory_base;
  pool.address_limit          = pool.memory_base + reserve;
  pool.commit_step            = commit_step;
}

get :: (pool: *Flat_Pool, nbytes: s64) -> *void {
  if !pool.memory_base  init(pool, commit_step = pool.commit_step);

  result := Align(pool.current_point, pool.alignment);
  end    := result + nbytes;

  if end > pool.first_uncommitted_page {
    assert(end <= pool.address_limit, "Flat_Pool % is full! (Allocation size %; alignment %; address space size %; already allocated %.)", pool, nbytes, pool.alignment, pool.address_limit - pool.memory_base, pool.current_point - pool.memory_base);
    if !commit_pages(pool, end)  return null;
  }

  pool.current_point = end;
  return result;
}

reset :: (pool: *Flat_Pool, overwrite_memory := false) {
  if !pool.memory_base  return;
  if overwrite_memory  memset(pool.memory_base, 0xcc, pool.current_point - pool.memory_base);
  pool.current_point = pool.memory_base;
}

fini :: (pool: *Flat_Pool) {
  if !pool.memory_base  return;
  #if DEBUG_MEMORY  _check_destroy_heap(.{ flat_pool_allocator_proc, pool });
  VirtualFree(pool.memory_base, 0, MEM_RELEASE);
  pool.memory_base = null;
}

flat_pool_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
  if #complete mode == {
    case .FREE;    return null;
    case .RESIZE;  #through;
    case .ALLOCATE;
      pool := cast(*Flat_Pool) allocator_data;
      assert(pool != null);

      result := get(pool, requested_size);
      if mode == .RESIZE {
        size_to_copy := min(old_size, requested_size);
        if result && size_to_copy  memcpy(result, old_memory, size_to_copy);
      }
      return result;

    case .STARTUP;  #through;
    case .SHUTDOWN;
      return null;

    case .THREAD_START;  #through;
    case .THREAD_STOP;
      assert(false, "Multithreaded access is not supported by flat_pool_allocator_proc.");
      return null;

    case .CREATE_HEAP;   #through;
    case .DESTROY_HEAP;
      assert(false, "Create/Destroy heap are not supported by flat_pool_allocator_proc.");
      return null;

    case .IS_THIS_YOURS;
      pool := cast(*Flat_Pool) allocator_data;
      result := (old_memory >= pool.memory_base) && (old_memory < pool.first_uncommitted_page);
      return cast(*void) cast(s64) result;

    case .CAPS;
      if old_memory { (cast(*string) old_memory).* = "Engine/Flat_Pool"; }
      return cast(*void) (Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR | .IS_THIS_YOURS);
  }
}

// Skips allocations inside a pool; commit_pages reports each committed chunk instead.
#if DEBUG_MEMORY {
  Engine_Memory_Debugger :: struct {
    check_alloc :: (allocator: Allocator, memory: *void, size: s64) {
      if allocator.proc == flat_pool_allocator_proc  return;
      _check_alloc(allocator, memory, size);
    }
    check_free :: (allocator: Allocator, memory: *void) {
      if allocator.proc == flat_pool_allocator_proc  return;
      _check_free(allocator, memory);
    }
    check_create_heap  :: (allocator: Allocator) { _check_create_heap(allocator); }
    check_destroy_heap :: (allocator: Allocator) { _check_destroy_heap(allocator); }
  }
} else {
  Engine_Memory_Debugger :: struct {
    check_alloc        :: (allocator: Allocator, memory: *void, size: s64) {}
    check_free         :: (allocator: Allocator, memory: *void) {}
    check_create_heap  :: (allocator: Allocator) {}
    check_destroy_heap :: (allocator: Allocator) {}
  }
}

#scope_file

#import "System";

PAGE_SIZE :: 4096;

Align :: inline (n: $T, $$ alignment: s64) -> T {
  return (n + alignment - 1) & ~(alignment - 1);
}

commit_pages :: (pool: *Flat_Pool, end: *u8) -> bool {
  size := Align(max(end - pool.first_uncommitted_page, pool.commit_step), PAGE_SIZE);
  size  = min(size, pool.address_limit - pool.first_uncommitted_page);
  if !VirtualAlloc(pool.first_uncommitted_page, cast(u64) size, MEM_COMMIT, PAGE_READWRITE) {
    log_os_error("VirtualAlloc MEM_COMMIT");
    return false;
  }
  #if DEBUG_MEMORY  _check_alloc(.{ flat_pool_allocator_proc, pool }, pool.first_uncommitted_page, size);
  pool.first_uncommitted_page += size;
  return true;
}

log_os_error :: (call: string) {
  code, description := get_error_value_and_string();
  log_error("In Flat_Pool, % failed with code %: %", call, code, description);
}
